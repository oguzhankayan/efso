// Account deletion — Apple Guideline 5.1.1 (in-app account deletion).
//
// Flow:
//   1. JWT validate (kullanıcı kendi hesabını siler)
//   2. Service-role ile user'a ait tüm row'ları sil (cascade)
//   3. Storage'dan screenshot'ları temizle
//   4. auth.users'tan user'ı sil (Supabase admin API)
//
// İade: 200 + { ok: true }. UI signOut + flag reset eder.

import { preflightOk, jsonResponse, errorResponse } from "../_shared/cors.ts";
import { requireAuth, AuthError } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return preflightOk();
  if (req.method !== "POST") return errorResponse("invalid_input", "POST only", 405);

  try {
    const { userId, serviceClient } = await requireAuth(req);

    // ─── 1. Storage temizliği — kullanıcının screenshot klasörü ───
    // Bucket policy zaten kullanıcı klasörünü kapsıyor, direkt list+remove.
    try {
      const { data: files } = await serviceClient.storage
        .from("screenshots")
        .list(userId, { limit: 1000 });
      const paths = (files ?? []).map((f) => `${userId}/${f.name}`);
      if (paths.length > 0) {
        await serviceClient.storage.from("screenshots").remove(paths);
      }
    } catch (e) {
      console.warn("storage cleanup warn", e instanceof Error ? e.message : e);
      // Storage temizliği fail olsa bile devam et — DB row'lar daha kritik.
    }

    // ─── 2. DB row'ları sil — RLS bypass, sırayla ───
    // FK cascade'e güvenmiyoruz; explicit sıralama daha güvenli.
    const tables = [
      "conversations",
      "security_events",
      "subscription_state",
      "usage_daily",
    ];
    for (const t of tables) {
      const { error } = await serviceClient.from(t).delete().eq("user_id", userId);
      if (error && !error.message.includes("not exist")) {
        console.error(`delete from ${t} failed`, error.message);
      }
    }
    // profiles tablosunda PK = id, user_id kolonundan değil id'den silinir
    await serviceClient.from("profiles").delete().eq("id", userId);

    // ─── 3. auth.users sil ───
    const { error: authErr } = await serviceClient.auth.admin.deleteUser(userId);
    if (authErr) {
      console.error("auth admin deleteUser failed", authErr.message);
      return errorResponse("internal", "auth delete failed", 500);
    }

    return jsonResponse({ ok: true, deleted_at: new Date().toISOString() });
  } catch (err) {
    if (err instanceof AuthError) return errorResponse("unauthenticated", err.message, err.status);
    console.error("delete-account error", err);
    return errorResponse("internal", String(err), 500);
  }
});
