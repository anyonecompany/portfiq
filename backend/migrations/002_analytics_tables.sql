-- ============================================================
-- Portfiq — Analytics Tables (Supabase / PostgreSQL)
-- Migration: 002_analytics_tables
-- Date: 2026-03-10
-- ============================================================

-- ──────────────────────────────────────────────
-- Drop old daily_metrics and recreate with new schema
-- (기존 001에서 만든 daily_metrics를 확장된 스키마로 교체)
-- ──────────────────────────────────────────────

-- 기존 daily_metrics에 새 컬럼 추가 (이미 존재하면 무시)
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS metric_date DATE;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS dau INT DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS new_users INT DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS onboarding_conversion NUMERIC(5,4) DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS d1_retention NUMERIC(5,4) DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS d7_retention NUMERIC(5,4) DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS d30_retention NUMERIC(5,4) DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS morning_push_ctr NUMERIC(5,4) DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS night_push_ctr NUMERIC(5,4) DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS aha_moment_rate NUMERIC(5,4) DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS avg_session_duration INT DEFAULT 0;
ALTER TABLE daily_metrics ADD COLUMN IF NOT EXISTS sessions_per_user NUMERIC(5,2) DEFAULT 0;

-- metric_date를 date 컬럼 값으로 백필 (기존 데이터 호환)
UPDATE daily_metrics SET metric_date = date WHERE metric_date IS NULL;

-- metric_date에 UNIQUE 제약 추가 (중복 방지)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'daily_metrics_metric_date_key'
    ) THEN
        ALTER TABLE daily_metrics ADD CONSTRAINT daily_metrics_metric_date_key UNIQUE (metric_date);
    END IF;
END $$;

-- ──────────────────────────────────────────────
-- Funnel cohorts (퍼널 코호트 집계)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS funnel_cohorts (
    id BIGSERIAL PRIMARY KEY,
    cohort_date DATE NOT NULL,
    step TEXT NOT NULL,
    step_order INT NOT NULL,
    user_count INT DEFAULT 0,
    conversion_from_prev NUMERIC(5,4) DEFAULT 0,
    conversion_from_top NUMERIC(5,4) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(cohort_date, step)
);

CREATE INDEX IF NOT EXISTS idx_funnel_cohorts_date ON funnel_cohorts (cohort_date DESC);
CREATE INDEX IF NOT EXISTS idx_funnel_cohorts_step ON funnel_cohorts (step);

-- ──────────────────────────────────────────────
-- Session metrics (세션별 상세 지표)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS session_metrics (
    id BIGSERIAL PRIMARY KEY,
    session_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_seconds INT DEFAULT 0,
    screens_visited INT DEFAULT 0,
    event_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_metrics_device ON session_metrics (device_id);
CREATE INDEX IF NOT EXISTS idx_session_metrics_started ON session_metrics (started_at DESC);

-- ──────────────────────────────────────────────
-- Push metrics (푸시 알림 지표)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS push_metrics (
    id BIGSERIAL PRIMARY KEY,
    metric_date DATE NOT NULL,
    push_type TEXT NOT NULL,
    sent_count INT DEFAULT 0,
    received_count INT DEFAULT 0,
    tapped_count INT DEFAULT 0,
    ctr NUMERIC(5,4) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(metric_date, push_type)
);

CREATE INDEX IF NOT EXISTS idx_push_metrics_date ON push_metrics (metric_date DESC);
CREATE INDEX IF NOT EXISTS idx_push_metrics_type ON push_metrics (push_type);
