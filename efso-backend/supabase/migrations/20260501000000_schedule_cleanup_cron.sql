-- Screenshot 24h auto-delete cron — Privacy Manifest sözünü gerçeklestirir.
--
-- ÖNEMLİ: Bu migration `supabase db push` ile gönderilmemeli (RLS yok,
-- vault secret okuma yetkisi gerek). Aşağıdaki SQL'i Supabase Dashboard
-- → SQL Editor'da bir kez manuel çalıştır.
--
-- Önkoşul (proje seviyesinde extension enable):
--   Supabase Dashboard → Database → Extensions → pg_cron + pg_net "ON"
--
-- Sonra Supabase Dashboard → Project Settings → Vault'a service role key'i
-- ekle (zaten yoksa):
--   key: service_role_key, value: <SERVICE_ROLE_KEY>
--
-- En son, aşağıdaki cron'u SQL Editor'da çalıştır:

select cron.schedule(
    'cleanup-old-screenshots',
    '0 * * * *',  -- her saat başı (screenshot'lar max ~25h'de silinir)
    $$
    select net.http_post(
        url := 'https://ftjdfcvlsqrjlvebbsqi.supabase.co/functions/v1/cleanup-storage',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key' limit 1)
        )
    );
    $$
);

-- Conversation 30-day cron (parse_result + generation_result null'lama).
-- Aynı pattern. cleanup-storage function her iki retention'ı da handle ediyor;
-- tek schedule yeterli.

-- Kontrol:
--   select * from cron.job;
--   select * from cron.job_run_details order by start_time desc limit 5;
