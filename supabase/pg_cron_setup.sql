-- ================================================================
-- Portfiq News Pipeline — pg_cron 스케줄 설정
-- ================================================================
-- Supabase Dashboard → SQL Editor에서 실행하세요.
-- service_role_key를 아래 <YOUR_SERVICE_ROLE_KEY>에 붙여넣으세요.
-- ================================================================

-- 1. 확장 활성화
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. 30분마다 Edge Function 호출
SELECT cron.schedule(
    'news-pipeline-every-30min',
    '*/30 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://bhwxbpwadinnkqzsiwsy.supabase.co/functions/v1/news-pipeline',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer <YOUR_SERVICE_ROLE_KEY>"}'::jsonb,
        body := '{"trigger": "cron"}'::jsonb
    );
    $$
);

-- 3. 등록 확인
SELECT * FROM cron.job WHERE jobname = 'news-pipeline-every-30min';

-- ================================================================
-- 삭제하려면:
-- SELECT cron.unschedule('news-pipeline-every-30min');
-- ================================================================
