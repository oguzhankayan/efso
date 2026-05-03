// POST /functions/v1/revenuecat-webhook
// RevenueCat → Supabase subscription_state sync.
//
// Events: INITIAL_PURCHASE, RENEWAL, CANCELLATION, EXPIRATION,
//         PRODUCT_CHANGE, BILLING_ISSUE, NON_RENEWING_PURCHASE.
//
// Auth: shared bearer token (REVENUECAT_WEBHOOK_SECRET env var).
// RevenueCat dashboard'da Authorization header'da gönderilir.

import { jsonResponse, errorResponse } from "../_shared/cors.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";

interface RCEvent {
  type: string;
  app_user_id: string;
  aliases?: string[];
  original_app_user_id?: string;
  transferred_from?: string[];
  transferred_to?: string[];
  product_id?: string;
  expiration_at_ms?: number;
  purchased_at_ms?: number;
  store?: string;
  environment?: "SANDBOX" | "PRODUCTION";
}

interface RCBody {
  event: RCEvent;
  api_version: string;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const ACTIVE_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "NON_RENEWING_PURCHASE",
  "UNCANCELLATION",
]);

const INACTIVE_TYPES = new Set([
  "CANCELLATION",
  "EXPIRATION",
  "BILLING_ISSUE",
]);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return errorResponse("invalid_input", "POST only", 405);

  // Shared-secret auth — REVENUECAT_WEBHOOK_SECRET must be configured.
  // If missing, reject all requests to prevent unauthenticated access.
  if (!WEBHOOK_SECRET) {
    console.error("REVENUECAT_WEBHOOK_SECRET not configured");
    return errorResponse("internal", "webhook not configured", 500);
  }
  const authHeader = req.headers.get("authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (token !== WEBHOOK_SECRET) {
    return errorResponse("unauthenticated", "invalid webhook secret", 401);
  }

  let body: RCBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse("invalid_input", "invalid json");
  }

  const ev = body?.event;
  if (!ev?.type || !ev.app_user_id) {
    return errorResponse("invalid_input", "missing event fields");
  }

  const isActive = ACTIVE_TYPES.has(ev.type);
  const isInactive = INACTIVE_TYPES.has(ev.type);
  if (!isActive && !isInactive) {
    // TEST event veya bilinmeyen — 200 dön ki RC retry yapmasın.
    return jsonResponse({ ok: true, ignored: ev.type });
  }

  const candidateIds = [
    ev.app_user_id,
    ev.original_app_user_id,
    ...(ev.aliases ?? []),
    ...(ev.transferred_to ?? []),
    ...(ev.transferred_from ?? []),
  ].filter((id): id is string => Boolean(id));
  const userId = candidateIds.find(id => UUID_RE.test(id));
  if (!userId) {
    console.warn("non-UUID RevenueCat customer ignored:", ev.app_user_id.slice(0, 30));
    return jsonResponse({ ok: true, ignored: "non_uuid_user" });
  }
  const revenuecatCustomerId = candidateIds.find(id => !UUID_RE.test(id)) ?? ev.app_user_id;

  const client = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { persistSession: false },
  });

  const expirationISO = ev.expiration_at_ms
    ? new Date(ev.expiration_at_ms).toISOString()
    : null;
  const purchaseISO = ev.purchased_at_ms
    ? new Date(ev.purchased_at_ms).toISOString()
    : null;

  const { error } = await client.from("subscription_state").upsert(
    {
      user_id: userId,
      is_active: isActive,
      entitlement: isActive ? "premium" : null,
      will_renew: ev.type !== "CANCELLATION" && isActive,
      product_identifier: ev.product_id ?? null,
      purchase_date: purchaseISO,
      expiration_date: expirationISO,
      revenuecat_customer_id: revenuecatCustomerId,
    },
    { onConflict: "user_id" },
  );

  if (error) {
    console.error("subscription_state upsert failed", error.message);
    return errorResponse("internal", "upsert failed", 500);
  }

  return jsonResponse({ ok: true, type: ev.type, active: isActive });
});
