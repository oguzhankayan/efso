// POST /functions/v1/refine-reply
// Regenerate one existing reply in a new Efso tone.

import { corsHeaders, preflightOk, errorResponse, jsonResponse } from "../_shared/cors.ts";
import { requireAuth, AuthError } from "../_shared/auth.ts";
import { loadPrompt } from "../_shared/prompt-loader.ts";
import { todayIstanbulISODate } from "../_shared/dates.ts";
import { callOpenAIResponsesJSON, openaiResponsesCostUSD } from "../_shared/llm-client.ts";
import type { Mode, Tone, GenerationResult, ReplyOption } from "../_shared/types.ts";

const FREE_REFINE_LIMIT = 10;
const COST_CEILING_USD = 0.50;
const VALID_TONES = new Set<Tone>(["flortoz", "esprili", "direkt", "sicak", "gizemli"]);

interface RequestBody {
  conversation_id: string;
  reply_index: number;
  tone: Tone;
}

interface RefineOutput {
  reply: {
    index: number;
    tone: Tone;
    text: string;
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return preflightOk();
  if (req.method !== "POST") return errorResponse("invalid_input", "POST only", 405);

  try {
    const { userId, client, serviceClient } = await requireAuth(req);
    const body = (await req.json().catch(() => null)) as RequestBody | null;
    if (!body?.conversation_id || typeof body.reply_index !== "number" || !VALID_TONES.has(body.tone)) {
      return errorResponse("invalid_input", "conversation_id, reply_index and tone required");
    }
    if (body.reply_index < 0 || body.reply_index > 2) {
      return errorResponse("invalid_input", "reply_index must be 0...2");
    }

    const today = todayIstanbulISODate();
    const [profileResult, convResult, subResult, usageResult] = await Promise.all([
      client
        .from("profiles")
        .select("ai_consent_given, archetype_primary, archetype_secondary, calibration_data, voice_sample, gender, age_bracket, intent")
        .eq("id", userId)
        .maybeSingle(),
      client
        .from("conversations")
        .select("id, mode, parse_result, generation_result, extra_context")
        .eq("id", body.conversation_id)
        .eq("user_id", userId)
        .maybeSingle(),
      client
        .from("subscription_state")
        .select("is_active")
        .eq("user_id", userId)
        .maybeSingle(),
      client
        .from("usage_daily")
        .select("refine_count, llm_cost_usd")
        .eq("user_id", userId)
        .eq("date", today)
        .maybeSingle(),
    ]);

    const profile = profileResult.data;
    if (!profile?.ai_consent_given) {
      return new Response(JSON.stringify({ error: "ai_consent_required" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const conv = convResult.data;
    if (convResult.error || !conv) {
      return errorResponse("invalid_input", "conversation not found");
    }
    const generation = conv.generation_result as GenerationResult | null;
    if (!generation?.replies?.length) {
      return errorResponse("invalid_input", "conversation has no replies");
    }
    const original = generation.replies.find(r => r.index === body.reply_index);
    if (!original) {
      return errorResponse("invalid_input", "reply not found");
    }

    const isPremium = subResult.data?.is_active === true;
    const todayRefines = usageResult.data?.refine_count ?? 0;
    const todayCostUSD = Number(usageResult.data?.llm_cost_usd ?? 0);
    if (!isPremium && todayRefines >= FREE_REFINE_LIMIT) {
      return errorResponse("free_tier_exceeded", "günlük 10 tonlama doldu", 402);
    }
    if (todayCostUSD >= COST_CEILING_USD) {
      return errorResponse("rate_limited", "günlük üretim limitin doldu, yarın tekrar dene", 429);
    }

    const prompt = await buildRefinePrompt(client, conv.mode as Mode, body.tone, profile);
    const response = await callOpenAIResponsesJSON<RefineOutput>({
      instructions: prompt,
      input: [{
        type: "input_text",
        text: JSON.stringify({
          mode: conv.mode,
          parse_result: conv.parse_result ?? {},
          existing_observation: generation.observation ?? "",
          existing_replies: generation.replies,
          original_reply: original,
          target_tone: body.tone,
          extra_context: conv.extra_context ?? null,
        }),
      }],
      schemaName: "efso_refine_reply",
      schema: refineSchema(),
      maxOutputTokens: 500,
      temperature: 0.85,
    });

    const reply: ReplyOption = {
      index: body.reply_index,
      tone: VALID_TONES.has(response.parsed.reply.tone) ? response.parsed.reply.tone : body.tone,
      text: response.parsed.reply.text.trim(),
    };
    if (!reply.text) {
      return errorResponse("llm_failure", "empty refined reply", 502);
    }

    const updated: GenerationResult = {
      ...generation,
      replies: generation.replies.map(r => r.index === body.reply_index ? reply : r),
    };
    const cost = openaiResponsesCostUSD(response.usage);
    await Promise.all([
      serviceClient.rpc("fn_increment_refine", { p_user_id: userId, p_cost_usd: cost }),
      serviceClient
        .from("conversations")
        .update({
          generation_result: updated,
        })
        .eq("id", conv.id),
    ]);

    const remainingRefines = isPremium ? null : Math.max(0, FREE_REFINE_LIMIT - (todayRefines + 1));
    return jsonResponse({
      reply,
      remaining_refines_today: remainingRefines,
      is_premium: isPremium,
    });
  } catch (err) {
    if (err instanceof AuthError) return errorResponse("unauthenticated", err.message, err.status);
    console.error("refine-reply unexpected error", err);
    return errorResponse("internal", String(err), 500);
  }
});

async function buildRefinePrompt(
  client: Awaited<ReturnType<typeof requireAuth>>["client"],
  mode: Mode,
  tone: Tone,
  profile: Record<string, unknown> | null,
): Promise<string> {
  const archetypeKey = (profile?.archetype_primary as string | undefined) ?? "observer";
  const [L0, L1, L2, tonePrompt, archetypePrompt] = await Promise.all([
    loadPrompt(client, { layer: "L0" }),
    loadPrompt(client, { layer: "L1", mode }),
    loadPrompt(client, { layer: "L2" }),
    loadPrompt(client, { layer: "tone", tone }),
    loadPrompt(client, { layer: "archetype", archetype: archetypeKey as never }).catch(() => null),
  ]);
  return [
    L0.content,
    L2.content,
    L1.content,
    archetypePrompt?.content ? `--- archetype ---\n${archetypePrompt.content}` : "",
    `--- target tone (${tone}) ---\n${tonePrompt.content}`,
    `Rewrite only one reply.
Keep the same conversational context and intent.
Do not explain.
Do not include assistant voice in the reply.
Return only JSON matching the schema.
The reply index must stay the requested index and tone must be ${tone}.`,
  ].filter(Boolean).join("\n\n");
}

function refineSchema(): Record<string, unknown> {
  return {
    type: "object",
    additionalProperties: false,
    required: ["reply"],
    properties: {
      reply: {
        type: "object",
        additionalProperties: false,
        required: ["index", "tone", "text"],
        properties: {
          index: { type: "integer", enum: [0, 1, 2] },
          tone: { type: "string", enum: ["flortoz", "esprili", "direkt", "sicak", "gizemli"] },
          text: { type: "string" },
        },
      },
    },
  };
}
