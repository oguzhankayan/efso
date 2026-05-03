-- screenshots bucket — private, 24h retention via cron

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'screenshots',
    'screenshots',
    FALSE,
    10 * 1024 * 1024,  -- 10MB max
    ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- RLS: users can only insert/select their own files (path: <user_id>/<uuid>.jpg)
CREATE POLICY "Users upload to own folder"
    ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'screenshots'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Users read own screenshots"
    ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'screenshots'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

CREATE POLICY "Users delete own screenshots"
    ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'screenshots'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ──────────────────────────────────────────────────────────
-- 24h retention: cron job removes screenshot files + nullifies path
-- ──────────────────────────────────────────────────────────
-- Schedule via supabase dashboard or pg_cron extension after deploy:
--   SELECT cron.schedule(
--       'cleanup-old-screenshots',
--       '0 * * * *',  -- her saat başı
--       $$ SELECT net.http_post(
--           url := concat(current_setting('app.settings.supabase_url'), '/functions/v1/cleanup-storage'),
--           headers := jsonb_build_object('Authorization', concat('Bearer ', current_setting('app.settings.service_role_key')))
--       ); $$
--   );
