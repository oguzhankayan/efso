// Shared types — Edge Functions across efso backend

// Tonla = kullanıcı taslağını seçilen tona çevirir (ss yok, text input).
// Bio Phase 7+'a ertelendi.
export type Mode = "cevap" | "acilis" | "tonla" | "davet";
export type Tone = "flortoz" | "esprili" | "direkt" | "sicak" | "gizemli";
export type Platform =
  | "tinder" | "bumble" | "hinge" | "instagram"
  | "twitter" | "linkedin"
  | "imessage" | "whatsapp" | "unknown";

export type Gender = "male" | "female" | "unspecified";
export type AgeBracket = "18-24" | "25-34" | "35-44" | "45+";
export type Intent = "relationship" | "casual" | "fun" | "taken";

export type ArchetypePrimary =
  | "dryroaster" | "observer" | "softie_with_edges"
  | "chaos_agent" | "strategist" | "romantic_pessimist";

// ──────────────────────────────────────────────────────────
// Stage 1 — Parse result
// ──────────────────────────────────────────────────────────
export type ScreenshotType = "chat" | "profile";

export interface ParseSummary {
  platform: Platform;
  screenshot_type: ScreenshotType | "draft";
  context_summary_tr: string;
  injection_attempt: boolean;
}

export interface ProfileExtract {
  name?: string | null;
  handle?: string | null;        // @username (insta/twitter/etc)
  age?: number | null;
  bio?: string | null;
  prompts?: Array<{ question: string; answer: string }>;
  interests?: string[];
  job?: string | null;
  school?: string | null;
  location?: string | null;
  photo_count?: number;
  photo_descriptions?: string[];
  posts?: string[];              // post/tweet/caption alıntıları
}

export interface ParseResult {
  screenshot_type?: ScreenshotType;
  participants: Array<{ role: "user" | "other"; name?: string | null }>;
  messages: Array<{
    sender: "user" | "other";
    text: string;
    order: number;
    approximate_time?: string | null;
  }>;
  last_message_from: "user" | "other" | null;
  profile?: ProfileExtract;
  platform_detected: Platform;
  tone_observed:
    | "warm" | "neutral" | "dry" | "cold" | "hostile"
    | "playful" | "invested" | "disengaged";
  red_flags: string[];
  context_summary_tr: string;
  injection_attempt: boolean;
  image_quality: "good" | "fair" | "poor";
}

// ──────────────────────────────────────────────────────────
// Stage 2 — Generate replies
// ──────────────────────────────────────────────────────────
export interface ReplyOption {
  index: number;
  tone: Tone | "silence";   // her reply farklı tonda. 'silence' sadece hayalet modu için.
  text: string;
}

export interface GenerationResult {
  observation: string;       // Asistan sesi — italic obs cards
  replies: ReplyOption[];    // Output sesi — reply cards
  duration_ms: number;
}

export interface RefineResult {
  reply: ReplyOption;
  remaining_refines_today: number | null;
  is_premium: boolean;
}

// ──────────────────────────────────────────────────────────
// Calibration
// ──────────────────────────────────────────────────────────
export interface CalibrationAnswer {
  question_id: string;
  selected: string | string[];
  free_text?: string;
}

export interface ArchetypeResult {
  archetype_primary: ArchetypePrimary;
  archetype_secondary: ArchetypePrimary;
  display_label: string;          // "🥀 EFSO"
  display_description: string[];  // 3 davranışsal cümle
  traits: Record<string, number>;
  full_profile: Record<string, unknown>;
}

// ──────────────────────────────────────────────────────────
// Profile (DB row)
// ──────────────────────────────────────────────────────────
export interface Profile {
  id: string;
  gender: Gender | null;
  age_bracket: AgeBracket | null;
  intent: Intent | null;
  archetype_primary: ArchetypePrimary | null;
  archetype_secondary: ArchetypePrimary | null;
  calibration_data: Record<string, unknown> | null;
  notifications_enabled: boolean;
  ai_consent_given: boolean;
  total_generations: number;
}

// ──────────────────────────────────────────────────────────
// Errors
// ──────────────────────────────────────────────────────────
export type ErrorCode =
  | "unauthenticated"
  | "rate_limited"
  | "free_tier_exceeded"
  | "invalid_input"
  | "injection_blocked"
  | "llm_failure"
  | "unsupported_image"
  | "internal";

export interface ApiError {
  code: ErrorCode;
  message: string;
  details?: unknown;
}
