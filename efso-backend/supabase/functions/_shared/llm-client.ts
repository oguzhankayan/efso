// LLM client — Anthropic Claude Sonnet 4.6 + OpenAI GPT-4o-mini.
//
// Anthropic: Stage 2 generation, streaming SSE, prompt caching on L0/L2/L4.
// OpenAI: Stage 1 vision parse, structured JSON output.
//
// Key'ler env'den okunur, asla log'lanmaz.

import type { ParseResult } from "./types.ts";

// ──────────────────────────────────────────────────────────
// Config
// ──────────────────────────────────────────────────────────

const ANTHROPIC_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ANTHROPIC_MODEL = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6";
const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";

const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const OPENAI_MODEL = Deno.env.get("OPENAI_VISION_MODEL") ?? "gpt-4o-mini";
const OPENAI_API = "https://api.openai.com/v1/chat/completions";

// Cost per million tokens (USD). Update if pricing changes.
const COST_PER_MTOK = {
  anthropic_input: 3.0,
  anthropic_cache_write: 3.75,
  anthropic_cache_read: 0.30,
  anthropic_output: 15.0,
  openai_input: 0.15,    // gpt-4o-mini input
  openai_output: 0.60,   // gpt-4o-mini output
};

// ──────────────────────────────────────────────────────────
// Anthropic — streaming generation
// ──────────────────────────────────────────────────────────

export interface AnthropicSystemBlock {
  type: "text";
  text: string;
  cache_control?: { type: "ephemeral" };
}

export interface AnthropicMessage {
  role: "user" | "assistant";
  content: string;
}

export interface AnthropicStreamRequest {
  system: AnthropicSystemBlock[];   // multi-block, cache_control on shared layers
  messages: AnthropicMessage[];
  maxTokens?: number;
  temperature?: number;
}

export interface AnthropicUsage {
  input_tokens: number;
  output_tokens: number;
  cache_creation_input_tokens?: number;
  cache_read_input_tokens?: number;
}

/// Cost of an Anthropic call given usage.
export function anthropicCostUSD(u: AnthropicUsage): number {
  const inputTok = u.input_tokens || 0;
  const outputTok = u.output_tokens || 0;
  const cacheWrite = u.cache_creation_input_tokens || 0;
  const cacheRead = u.cache_read_input_tokens || 0;

  return (
    (inputTok * COST_PER_MTOK.anthropic_input
      + cacheWrite * COST_PER_MTOK.anthropic_cache_write
      + cacheRead * COST_PER_MTOK.anthropic_cache_read
      + outputTok * COST_PER_MTOK.anthropic_output) / 1_000_000
  );
}

export interface StreamEvent {
  type: "text_delta" | "message_start" | "message_stop" | "error";
  text?: string;
  usage?: AnthropicUsage;
  error?: string;
}

/// Stream an Anthropic generation.
/// Yields events; consumer interprets text_delta as it arrives.
export async function* streamAnthropic(
  req: AnthropicStreamRequest,
): AsyncGenerator<StreamEvent> {
  if (!ANTHROPIC_KEY) {
    yield { type: "error", error: "ANTHROPIC_API_KEY not configured" };
    return;
  }

  const body = {
    model: ANTHROPIC_MODEL,
    max_tokens: req.maxTokens ?? 1500,
    temperature: req.temperature ?? 0.85,
    stream: true,
    system: req.system,
    messages: req.messages,
  };

  let response: Response;
  try {
    response = await fetch(ANTHROPIC_API, {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_KEY,
        "anthropic-version": "2023-06-01",
        "anthropic-beta": "prompt-caching-2024-07-31",
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(25_000),
    });
  } catch (e) {
    yield { type: "error", error: `network: ${e instanceof Error ? e.message : String(e)}` };
    return;
  }

  if (!response.ok || !response.body) {
    const txt = await response.text().catch(() => "");
    yield { type: "error", error: `anthropic ${response.status}: ${txt.slice(0, 300)}` };
    return;
  }

  let usage: AnthropicUsage | undefined;
  let buffer = "";
  const reader = response.body.getReader();
  const decoder = new TextDecoder();

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    // SSE events separated by \n\n
    let idx;
    while ((idx = buffer.indexOf("\n\n")) >= 0) {
      const chunk = buffer.slice(0, idx);
      buffer = buffer.slice(idx + 2);
      const eventLine = chunk.split("\n").find((l) => l.startsWith("data:"));
      if (!eventLine) continue;
      const dataStr = eventLine.replace(/^data:\s*/, "");
      if (!dataStr || dataStr === "[DONE]") continue;

      try {
        const evt = JSON.parse(dataStr);
        switch (evt.type) {
          case "message_start":
            usage = evt.message?.usage;
            yield { type: "message_start", usage };
            break;
          case "content_block_delta":
            if (evt.delta?.type === "text_delta") {
              yield { type: "text_delta", text: evt.delta.text ?? "" };
            }
            break;
          case "message_delta":
            if (evt.usage) {
              usage = { ...(usage ?? { input_tokens: 0, output_tokens: 0 }), ...evt.usage };
            }
            break;
          case "message_stop":
            yield { type: "message_stop", usage };
            break;
        }
      } catch {
        // Skip malformed events
      }
    }
  }
}

// ──────────────────────────────────────────────────────────
// OpenAI GPT-4o-mini — vision parse (Stage 1)
// Master prompt §2 listed alternative to Gemini.
// ──────────────────────────────────────────────────────────

export interface VisionParseRequest {
  systemPrompt: string;       // stage1_parser.md content
  imageBase64: string;
  imageMimeType: string;
}

export interface VisionUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

export interface VisionParseResponse {
  parseResult: ParseResult;
  usage: VisionUsage;
  durationMs: number;
  model: string;
}

export function visionCostUSD(u: VisionUsage): number {
  return (
    (u.prompt_tokens * COST_PER_MTOK.openai_input
      + u.completion_tokens * COST_PER_MTOK.openai_output) / 1_000_000
  );
}

export async function callVisionParse(
  req: VisionParseRequest,
): Promise<VisionParseResponse> {
  if (!OPENAI_KEY) {
    throw new Error("OPENAI_API_KEY not configured");
  }

  const start = Date.now();
  const dataUri = `data:${req.imageMimeType};base64,${req.imageBase64}`;

  const body = {
    model: OPENAI_MODEL,
    temperature: 0.2,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: req.systemPrompt },
      {
        role: "user",
        content: [
          { type: "text", text: "Analyze this screenshot. Return ONLY the JSON specified." },
          { type: "image_url", image_url: { url: dataUri, detail: "high" } },
        ],
      },
    ],
  };

  const response = await fetch(OPENAI_API, {
    method: "POST",
    headers: {
      "authorization": `Bearer ${OPENAI_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(20_000),
  });

  if (!response.ok) {
    const txt = await response.text().catch(() => "");
    throw new Error(`openai ${response.status}: ${txt.slice(0, 300)}`);
  }

  const data = await response.json();
  const text: string = data?.choices?.[0]?.message?.content ?? "";
  if (!text) throw new Error("openai: empty response");

  let parseResult: ParseResult;
  try {
    parseResult = JSON.parse(text);
  } catch (e) {
    throw new Error(`openai: invalid JSON: ${e instanceof Error ? e.message : e}`);
  }

  const usage: VisionUsage = {
    prompt_tokens: data?.usage?.prompt_tokens ?? 0,
    completion_tokens: data?.usage?.completion_tokens ?? 0,
    total_tokens: data?.usage?.total_tokens ?? 0,
  };

  return {
    parseResult,
    usage,
    durationMs: Date.now() - start,
    model: OPENAI_MODEL,
  };
}

// ──────────────────────────────────────────────────────────
// OpenAI GPT-4o — Stage 2 fallback (non-streaming)
// ──────────────────────────────────────────────────────────

const OPENAI_FALLBACK_MODEL = Deno.env.get("OPENAI_FALLBACK_MODEL") ?? "gpt-4o";

export interface FallbackGenerationRequest {
  systemPrompt: string;
  userPrompt: string;
  maxTokens?: number;
  temperature?: number;
}

export interface FallbackGenerationResponse {
  text: string;
  usage: VisionUsage;
  durationMs: number;
  model: string;
}

export function openaiGenerationCostUSD(u: VisionUsage): number {
  // gpt-4o: $2.50/M input, $10/M output
  return (u.prompt_tokens * 2.50 + u.completion_tokens * 10.0) / 1_000_000;
}

export async function callOpenAIFallback(
  req: FallbackGenerationRequest,
): Promise<FallbackGenerationResponse> {
  if (!OPENAI_KEY) throw new Error("OPENAI_API_KEY not configured");

  const start = Date.now();
  const body = {
    model: OPENAI_FALLBACK_MODEL,
    temperature: req.temperature ?? 0.85,
    max_tokens: req.maxTokens ?? 1500,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: req.systemPrompt },
      { role: "user", content: req.userPrompt },
    ],
  };

  const response = await fetch(OPENAI_API, {
    method: "POST",
    headers: {
      "authorization": `Bearer ${OPENAI_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(25_000),
  });

  if (!response.ok) {
    const txt = await response.text().catch(() => "");
    throw new Error(`openai fallback ${response.status}: ${txt.slice(0, 300)}`);
  }

  const data = await response.json();
  const text: string = data?.choices?.[0]?.message?.content ?? "";
  if (!text) throw new Error("openai fallback: empty response");

  return {
    text,
    usage: {
      prompt_tokens: data?.usage?.prompt_tokens ?? 0,
      completion_tokens: data?.usage?.completion_tokens ?? 0,
      total_tokens: data?.usage?.total_tokens ?? 0,
    },
    durationMs: Date.now() - start,
    model: OPENAI_FALLBACK_MODEL,
  };
}

// ──────────────────────────────────────────────────────────
// Output filter — toxic positivity detector
// ──────────────────────────────────────────────────────────

const TOXIC_POSITIVITY_PATTERNS: RegExp[] = [
  /sen değerlisin/i,
  /sen harikasın/i,
  /kendine inan/i,
  /her şey güzel olacak/i,
  /güçlüsün/i,
  /pozitif kal/i,
  /seni anlıyorum/i,
];

/// Return true if text contains coaching cliché — caller should regenerate.
export function hasToxicPositivity(text: string): boolean {
  return TOXIC_POSITIVITY_PATTERNS.some((re) => re.test(text));
}

// ──────────────────────────────────────────────────────────
// Helper — build system blocks with cache_control for max savings
// ──────────────────────────────────────────────────────────

/// L0 + L2 + L4 (rarely change) → single cached block.
/// L1 (mode-specific) + archetype + tone → uncached block (changes per request).
///
/// Archetype prompt buraya inject ediliyor (2026-04-30); öncesinde tarz sadece
/// L4 runtime template'inde bir satır olarak vardı, LLM çıkışında tone'un
/// altında ezilirdi. Şimdi tone gibi kendi fragmentıyla geliyor.
export function buildSystemBlocks(args: {
  L0: string;
  L1: string;
  L2: string;
  L4: string;
  tone: string;
  archetype?: string;
}): AnthropicSystemBlock[] {
  const stableContent = [args.L0, args.L2, args.L4].join("\n\n---\n\n");
  const archetypeBlock = args.archetype
    ? `\n--- archetype prompt (kullanıcı kim, NASIL yazar) ---\n${args.archetype}`
    : "";
  return [
    {
      type: "text",
      text: stableContent,
      cache_control: { type: "ephemeral" },
    },
    {
      type: "text",
      text: `\n--- mode prompt ---\n${args.L1}${archetypeBlock}\n\n--- tone prompt (her reply için ayrı) ---\n${args.tone}`,
    },
  ];
}
