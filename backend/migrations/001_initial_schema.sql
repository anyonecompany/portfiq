-- ============================================================
-- Portfiq — Initial Database Schema (Supabase / PostgreSQL)
-- Migration: 001_initial_schema
-- Date: 2026-03-10
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ──────────────────────────────────────────────
-- Devices (anonymous users identified by device_id)
-- ──────────────────────────────────────────────
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT UNIQUE NOT NULL,
    platform TEXT,                -- "ios" / "android"
    app_version TEXT,
    push_token TEXT,              -- FCM token for push notifications
    timezone TEXT DEFAULT 'Asia/Seoul',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_devices_device_id ON devices (device_id);

-- ──────────────────────────────────────────────
-- ETF Master data
-- ──────────────────────────────────────────────
CREATE TABLE etf_master (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticker TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    expense_ratio NUMERIC(5, 4),
    top_holdings TEXT[],           -- Array of ticker symbols
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_etf_master_ticker ON etf_master (ticker);
CREATE INDEX idx_etf_master_category ON etf_master (category);

-- ──────────────────────────────────────────────
-- Device-ETF watchlist (many-to-many)
-- ──────────────────────────────────────────────
CREATE TABLE device_etfs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    ticker TEXT NOT NULL REFERENCES etf_master(ticker) ON DELETE CASCADE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (device_id, ticker)
);

CREATE INDEX idx_device_etfs_device ON device_etfs (device_id);
CREATE INDEX idx_device_etfs_ticker ON device_etfs (ticker);

-- ──────────────────────────────────────────────
-- News articles
-- ──────────────────────────────────────────────
CREATE TABLE news (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    headline TEXT NOT NULL,
    impact_reason TEXT,
    source TEXT,
    source_url TEXT,
    published_at TIMESTAMPTZ,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    raw_data JSONB                -- Original API response
);

CREATE INDEX idx_news_published ON news (published_at DESC);

-- News-ETF impact mapping
CREATE TABLE news_impacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    news_id UUID NOT NULL REFERENCES news(id) ON DELETE CASCADE,
    etf_ticker TEXT NOT NULL REFERENCES etf_master(ticker),
    impact_level TEXT NOT NULL CHECK (impact_level IN ('High', 'Medium', 'Low')),
    impact_score NUMERIC(3, 2),   -- 0.00 - 1.00
    UNIQUE (news_id, etf_ticker)
);

CREATE INDEX idx_news_impacts_news ON news_impacts (news_id);
CREATE INDEX idx_news_impacts_ticker ON news_impacts (etf_ticker);

-- ──────────────────────────────────────────────
-- Briefings
-- ──────────────────────────────────────────────
CREATE TABLE briefings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL REFERENCES devices(device_id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('morning', 'night')),
    title TEXT NOT NULL,
    summary TEXT,
    etf_changes JSONB,            -- Array of {ticker, change_pct, direction, cause}
    checkpoints JSONB,            -- Array of checkpoint strings
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    prompt_tokens INT,
    completion_tokens INT,
    model TEXT
);

CREATE INDEX idx_briefings_device ON briefings (device_id, generated_at DESC);
CREATE INDEX idx_briefings_type ON briefings (type, generated_at DESC);

-- ──────────────────────────────────────────────
-- Analytics events
-- ──────────────────────────────────────────────
CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id TEXT NOT NULL,
    event_name TEXT NOT NULL,
    properties JSONB DEFAULT '{}',
    event_timestamp TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_events_device ON events (device_id, received_at DESC);
CREATE INDEX idx_events_name ON events (event_name);
CREATE INDEX idx_events_timestamp ON events (event_timestamp DESC);

-- ──────────────────────────────────────────────
-- Daily metrics (aggregated)
-- ──────────────────────────────────────────────
CREATE TABLE daily_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    date DATE NOT NULL UNIQUE,
    total_devices INT DEFAULT 0,
    active_devices INT DEFAULT 0,
    briefings_generated INT DEFAULT 0,
    news_fetched INT DEFAULT 0,
    events_received INT DEFAULT 0,
    avg_etfs_per_device NUMERIC(5, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_daily_metrics_date ON daily_metrics (date DESC);

-- ──────────────────────────────────────────────
-- Updated-at trigger function
-- ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_devices_updated_at
    BEFORE UPDATE ON devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_etf_master_updated_at
    BEFORE UPDATE ON etf_master
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
