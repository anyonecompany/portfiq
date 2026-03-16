-- ============================================================
-- Migration: 006_event_id_unique_and_api_cache
-- Date: 2026-03-16
-- Purpose: P2 이슈 해결 (event_id UUID 중복 방지) + API 캐시 테이블
-- ============================================================

-- 1. events 테이블에 event_id 컬럼 추가 (클라이언트에서 UUID v4 생성)
ALTER TABLE events ADD COLUMN IF NOT EXISTS event_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_events_event_id ON events(event_id) WHERE event_id IS NOT NULL;

-- 2. API 캐시 테이블 (3계층 캐시의 2계층 — Supabase DB 캐시)
CREATE TABLE IF NOT EXISTS api_cache (
    cache_key TEXT PRIMARY KEY,
    cache_value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    expired_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_api_cache_expire ON api_cache(expired_at);

-- 3. ETF 유니버스 테이블 (동적 확장용 — etf_master 보강)
CREATE TABLE IF NOT EXISTS etf_universe (
    ticker TEXT PRIMARY KEY,
    name TEXT,
    category TEXT DEFAULT 'other',
    app_category TEXT DEFAULT 'other',
    fund_family TEXT,
    expense_ratio NUMERIC(6,4),
    total_assets BIGINT,
    avg_volume BIGINT,
    description TEXT,
    exchange TEXT,
    currency TEXT DEFAULT 'USD',
    cached_at TIMESTAMPTZ DEFAULT now(),
    is_popular BOOLEAN DEFAULT false,
    search_count INTEGER DEFAULT 0
);
