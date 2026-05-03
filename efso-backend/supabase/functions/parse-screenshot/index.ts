// POST /functions/v1/parse-screenshot
// Stage 1 — Vision parse via GPT-4o-mini.
//
// Flow:
//   1. JWT validate, user_id extract
//   2. multipart parse (screenshot + mode)
//   3. Rate limit check (10/min/user)
//   4. Upload to storage: screenshots/<user_id>/<uuid>.<ext>
//   5. Call OpenAI vision with stage1_parser prompt + image
//   6. Validate ParseResult schema
//   7. If injection_attempt → log security_event, return 422
//   8. Insert conversations row, return { conversation_id, parse_result }

import { corsHeaders, preflightOk, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { requireAuth, AuthError } from "../_shared/auth.ts";
import { loadPrompt } from "../_shared/prompt-loader.ts";
import { callVisionParse, visionCostUSD } from "../_shared/llm-client.ts";
import type { Mode, ParseResult } from "../_shared/types.ts";

const ALLOWED_MIME = new Set(["image/jpeg", "image/png", "image/heic", "image/webp"]);
const MAX_BYTES = 10 * 1024 * 1024;
const RATE_LIMIT_PER_MIN = 10;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return preflightOk();
  if (req.method !== "POST") return errorResponse("invalid_input", "POST only", 405);

  try {
    const { userId, client, serviceClient } = await requireAuth(req);

    // ─── AI consent check ───
    const { data: consentProfile } = await client
      .from("profiles")
      .select("ai_consent_given")
      .eq("id", userId)
      .single();

    if (!consentProfile?.ai_consent_given) {
      return new Response(JSON.stringify({ error: "ai_consent_required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ─── parse multipart ───
    const formData = await req.formData();
    const screenshot = formData.get("screenshot");
    const modeStr = formData.get("mode") as string | null;
    // "bilmem gereken bir şey?" - opsiyonel kullanıcı notu, screenshot'ı
    // okuyamadığı bağlamı LLM'e taşır. Trim + 500 char cap.
    const extraContextRaw = formData.get("extra_context") as string | null;
    const extraContext = extraContextRaw?.trim().slice(0, 500) || null;

    // Manuel giriş: kullanıcı ss yerine konuşmayı/profili elle yazdığında
    // bu alan dolu gelir (JSON string). Vision call'ı atla, synthetic
    // ParseResult kur. Storage upload da yok (sadeceuser_id'ye row yazılır).
    const manualRaw = formData.get("manual_input") as string | null;
    const isManual = !!manualRaw;

    if (!modeStr || !["cevap", "acilis", "davet"].includes(modeStr)) {
      return errorResponse("invalid_input", "valid mode required");
    }
    const mode = modeStr as Mode;

    if (!isManual) {
      if (!(screenshot instanceof File)) {
        return errorResponse("invalid_input", "screenshot file or manual_input required");
      }
      if (!ALLOWED_MIME.has(screenshot.type)) {
        return errorResponse("unsupported_image", `mime ${screenshot.type} not allowed`);
      }
      if (screenshot.size > MAX_BYTES) {
        return errorResponse("invalid_input", `file too large (max ${MAX_BYTES} bytes)`);
      }
    }

    // ─── rate limit ───
    const sinceISO = new Date(Date.now() - 60_000).toISOString();
    const { count: recentCount, error: rlErr } = await serviceClient
      .from("conversations")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", sinceISO);

    if (rlErr) {
      console.error("rate limit query failed", rlErr);
    } else if ((recentCount ?? 0) >= RATE_LIMIT_PER_MIN) {
      return errorResponse("rate_limited", "10/min limit", 429);
    }

    // ─── upload to storage (sadece ss varsa) ───
    let storagePath: string | null = null;
    let fileBytes: Uint8Array | null = null;
    if (!isManual && screenshot instanceof File) {
      const ext = mimeToExt(screenshot.type);
      const objectId = crypto.randomUUID();
      storagePath = `${userId}/${objectId}.${ext}`;

      fileBytes = new Uint8Array(await screenshot.arrayBuffer());

      const { error: uploadErr } = await client.storage
        .from("screenshots")
        .upload(storagePath, fileBytes, {
          contentType: screenshot.type,
          upsert: false,
        });

      if (uploadErr) {
        console.error("storage upload failed", uploadErr.message);
        return errorResponse("internal", "upload failed", 500);
      }
    }

    // ─── parse ───
    // Manuel giriş: vision call atla, synthetic ParseResult kur.
    // Otomatik (ss): vision LLM çağır.
    let parsed: ParseResult;
    let parseModel = "manual";
    let parseDurationMs = 0;
    let parseCostUSD = 0;

    if (isManual) {
      try {
        parsed = buildManualParseResult(manualRaw!, mode);
      } catch (e) {
        return errorResponse(
          "invalid_input",
          e instanceof Error ? e.message : "manual_input parse failed",
        );
      }
    } else {
      const { content: stage1Prompt } = await loadPrompt(client, { layer: "stage1" });
      const imageBase64 = bytesToBase64(fileBytes!);
      let parseResp;
      try {
        parseResp = await callVisionParse({
          systemPrompt: stage1Prompt,
          imageBase64,
          imageMimeType: (screenshot as File).type,
        });
      } catch (e) {
        console.error("vision parse failed", e instanceof Error ? e.message : e);
        return errorResponse("llm_failure", "vision parse failed", 502);
      }
      parsed = parseResp.parseResult;
      parseModel = parseResp.model;
      parseDurationMs = parseResp.durationMs;
      parseCostUSD = visionCostUSD(parseResp.usage);
    }

    // ─── validate ───
    // Açılış modu profil ekranı bekler (insta/twitter/tinder/bumble/hinge,
    // herhangi bir sosyal/dating profili). Diğer modlar chat bekler.
    // Profil sayılması için: screenshot_type "profile" olmalı VEYA
    // mesaj yok + en az bir profil sinyali (bio/handle/post/photo_desc/prompt)
    // bulunmalı.
    const prof = parsed.profile;
    const hasProfileSignal = !!(
      prof && (
        (prof.bio && prof.bio.length > 0) ||
        (prof.handle && prof.handle.length > 0) ||
        (Array.isArray(prof.prompts) && prof.prompts.length > 0) ||
        (Array.isArray(prof.posts) && prof.posts.length > 0) ||
        (Array.isArray(prof.photo_descriptions) && prof.photo_descriptions.length > 0)
      )
    );
    const isProfileShot = parsed.screenshot_type === "profile"
      || (Array.isArray(parsed.messages) && parsed.messages.length === 0 && hasProfileSignal);

    if (mode === "acilis") {
      if (!isProfileShot) {
        return errorResponse(
          "unsupported_image",
          "açılış modu profil ekran görüntüsü bekliyor (chat değil). instagram, twitter, tinder, bumble, hinge — fark etmez.",
        );
      }
      // Boş profil — hiçbir sinyal yok, opener üretilemez.
      if (!hasProfileSignal) {
        return errorResponse(
          "unsupported_image",
          "profil çok az şey gösteriyor. bio, post veya foto görünür bir ss dene.",
        );
      }
    } else {
      // cevap, davet — chat ekranı
      if (isProfileShot || !parsed.messages || parsed.messages.length === 0) {
        return errorResponse(
          "unsupported_image",
          "bu mod chat ekran görüntüsü bekliyor",
        );
      }
    }

    if (parsed.injection_attempt) {
      // Log + return clean error (no leak of injection content)
      await serviceClient.from("security_events").insert({
        user_id: userId,
        event_type: "prompt_injection",
        detected_pattern: "injection_attempt flag set by stage1",
        raw_input_hash: fileBytes ? await sha256Hex(fileBytes) : null,
        action_taken: "blocked",
      });
      return errorResponse("injection_blocked", "image contained injection attempt", 422);
    }

    // ─── insert conversation row ───
    const { data: conv, error: insertErr } = await serviceClient
      .from("conversations")
      .insert({
        user_id: userId,
        mode,
        tone: "esprili", // placeholder; updated when /generate-replies is called
        screenshot_storage_path: storagePath,
        parse_result: parsed,
        parse_model: parseModel,
        parse_cost_usd: parseCostUSD,
        parse_duration_ms: parseDurationMs,
        extra_context: extraContext,
      })
      .select("id")
      .single();

    if (insertErr || !conv) {
      console.error("conversations insert failed", insertErr?.message);
      return errorResponse("internal", "db insert failed", 500);
    }

    return jsonResponse({
      conversation_id: conv.id,
      parse_result: parsed,
      duration_ms: parseDurationMs,
    });
  } catch (err) {
    if (err instanceof AuthError) return errorResponse("unauthenticated", err.message, err.status);
    console.error("parse-screenshot unexpected error", err);
    return errorResponse("internal", String(err), 500);
  }
});

function mimeToExt(mime: string): string {
  switch (mime) {
    case "image/jpeg": return "jpg";
    case "image/png": return "png";
    case "image/heic": return "heic";
    case "image/webp": return "webp";
    default: return "bin";
  }
}

function bytesToBase64(bytes: Uint8Array): string {
  // Chunked to avoid call-stack limits
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode.apply(
      null,
      Array.from(bytes.subarray(i, i + chunkSize)) as unknown as number[],
    );
  }
  return btoa(binary);
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// ──────────────────────────────────────────────────────────
// Manual input → synthetic ParseResult
// ──────────────────────────────────────────────────────────
//
// Beklenen JSON shape:
// {
//   "messages": [{ "sender": "user"|"other", "text": "..." }, ...],   // cevap/davet
//   "other_name": "Selin",
//   "platform": "tinder",  // opsiyonel, default "unknown"
//   "profile": {            // açılış için
//     "bio": "...", "handle": "...",
//     "posts": ["..."], "photo_descriptions": ["..."]
//   }
// }
//
// Validasyon: messages max 30, her text ≤500 char. profile alanları ≤500 char.

interface ManualInput {
  messages?: Array<{ sender: "user" | "other"; text: string }>;
  other_name?: string;
  platform?: string;
  profile?: {
    bio?: string;
    handle?: string;
    posts?: string[];
    photo_descriptions?: string[];
    name?: string;
    age?: number;
  };
}

const MAX_MANUAL_MESSAGES = 30;
const MAX_TEXT_LEN = 500;

const INJECTION_PATTERNS: RegExp[] = [
  /ignore\s+(all\s+)?previous\s+instructions/i,
  /önceki\s+talimatları\s+unut/i,
  /sistem\s+prompt/i,
  /system\s+prompt/i,
  /you\s+are\s+now/i,
  /sen\s+artık/i,
  /disregard\s+(all\s+)?prior/i,
  /forget\s+(everything|all)/i,
  /new\s+instructions/i,
  /override\s+instructions/i,
];

function hasInjectionAttempt(text: string): boolean {
  return INJECTION_PATTERNS.some((re) => re.test(text));
}

function buildManualParseResult(raw: string, mode: Mode): ParseResult {
  let input: ManualInput;
  try {
    input = JSON.parse(raw);
  } catch {
    throw new Error("manual_input must be valid JSON");
  }

  const platform = (input.platform ?? "unknown") as ParseResult["platform_detected"];
  const otherName = input.other_name?.trim().slice(0, 50) || null;

  if (mode === "acilis") {
    const p = input.profile;
    if (!p) throw new Error("açılış için profile alanı zorunlu");
    const bio = p.bio?.trim().slice(0, MAX_TEXT_LEN) || null;
    const handle = p.handle?.trim().slice(0, 50) || null;
    const posts = (p.posts ?? [])
      .map((s) => s.trim().slice(0, MAX_TEXT_LEN))
      .filter((s) => s.length > 0)
      .slice(0, 10);
    const photoDescs = (p.photo_descriptions ?? [])
      .map((s) => s.trim().slice(0, MAX_TEXT_LEN))
      .filter((s) => s.length > 0)
      .slice(0, 10);
    if (!bio && !handle && posts.length === 0 && photoDescs.length === 0) {
      throw new Error("profil için en az bir alan dolu olmalı (bio/handle/post/foto)");
    }
    const allProfileText = [bio, handle, ...posts, ...photoDescs].filter(Boolean).join(" ");
    const injected = hasInjectionAttempt(allProfileText);
    return {
      screenshot_type: "profile",
      participants: [],
      messages: [],
      last_message_from: null,
      profile: {
        name: p.name?.trim().slice(0, 50) || null,
        handle,
        age: p.age ?? null,
        bio,
        prompts: [],
        interests: [],
        photo_count: photoDescs.length,
        photo_descriptions: photoDescs,
        posts,
      },
      platform_detected: platform,
      tone_observed: "neutral",
      red_flags: [],
      context_summary_tr: "manuel girilen profil",
      injection_attempt: injected,
      image_quality: "good",
    };
  }

  // chat shape (cevap, davet)
  const msgs = (input.messages ?? [])
    .filter((m) => m && (m.sender === "user" || m.sender === "other"))
    .map((m) => ({
      sender: m.sender,
      text: (m.text ?? "").trim().slice(0, MAX_TEXT_LEN),
    }))
    .filter((m) => m.text.length > 0)
    .slice(0, MAX_MANUAL_MESSAGES);

  if (msgs.length === 0) throw new Error("en az 1 mesaj gerekli");
  if (msgs[msgs.length - 1].sender !== "other") {
    throw new Error("son mesaj karşı taraftan olmalı (sen cevap üreteceksin)");
  }

  return {
    screenshot_type: "chat",
    participants: [
      { role: "user", name: null },
      { role: "other", name: otherName },
    ],
    messages: msgs.map((m, i) => ({
      sender: m.sender,
      text: m.text,
      order: i,
      approximate_time: null,
    })),
    last_message_from: msgs[msgs.length - 1].sender,
    platform_detected: platform,
    tone_observed: "neutral",
    red_flags: [],
    context_summary_tr: `manuel girilen ${msgs.length} mesajlık konuşma`,
    injection_attempt: msgs.some((m) => hasInjectionAttempt(m.text)),
    image_quality: "good",
  };
}
