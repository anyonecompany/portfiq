-- 004_news_feed_fixes.sql
-- Fix news table for feed data pipeline:
--   1. Add UNIQUE constraint on source_url for upsert deduplication
--   2. Add summary column (translated 3-line summary)
--   3. Add summary_3line column (bullet-point summary)
--   4. Add sentiment column (호재/중립/위험)

-- 1. Unique constraint on source_url (required for upsert ON CONFLICT)
ALTER TABLE news ADD CONSTRAINT uq_news_source_url UNIQUE (source_url);

-- 2. summary: translated impact summary (separate from impact_reason)
ALTER TABLE news ADD COLUMN IF NOT EXISTS summary TEXT;

-- 3. summary_3line: 3-bullet summary for feed cards
ALTER TABLE news ADD COLUMN IF NOT EXISTS summary_3line TEXT;

-- 4. sentiment: 호재 / 중립 / 위험
ALTER TABLE news ADD COLUMN IF NOT EXISTS sentiment TEXT DEFAULT '중립';
