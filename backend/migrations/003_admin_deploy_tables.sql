-- ============================================================
-- Portfiq — Admin & Deploy Tables
-- Migration: 003_admin_deploy_tables
-- Date: 2026-03-10
-- ============================================================

-- ──────────────────────────────────────────────
-- Admin users (internal dashboard accounts)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS admin_users (
    id BIGSERIAL PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('ceo', 'cto', 'pm')),
    totp_secret TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_admin_users_email ON admin_users (email);
CREATE INDEX idx_admin_users_role ON admin_users (role);

-- ──────────────────────────────────────────────
-- Deploy releases (release records)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS deploy_releases (
    release_id TEXT PRIMARY KEY,
    version TEXT NOT NULL,
    title TEXT NOT NULL,
    changelog TEXT,
    github_pr_url TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'deploying', 'deployed', 'failed')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_deploy_releases_status ON deploy_releases (status);
CREATE INDEX idx_deploy_releases_created ON deploy_releases (created_at DESC);

-- ──────────────────────────────────────────────
-- Deploy approvals (dual approval tracking)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS deploy_approvals (
    id BIGSERIAL PRIMARY KEY,
    release_id TEXT REFERENCES deploy_releases(release_id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('ceo', 'cto')),
    approved_by TEXT NOT NULL,
    approved_at TIMESTAMPTZ DEFAULT NOW(),
    totp_verified BOOLEAN DEFAULT FALSE,
    UNIQUE(release_id, role)
);

CREATE INDEX idx_deploy_approvals_release ON deploy_approvals (release_id);

-- ──────────────────────────────────────────────
-- Deploy history (execution records)
-- ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS deploy_history (
    id BIGSERIAL PRIMARY KEY,
    release_id TEXT REFERENCES deploy_releases(release_id) ON DELETE CASCADE,
    github_run_id TEXT,
    target_environment TEXT DEFAULT 'production' CHECK (target_environment IN ('staging', 'production')),
    triggered_by TEXT NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT DEFAULT 'running' CHECK (status IN ('running', 'deployed', 'failed')),
    error_log TEXT
);

CREATE INDEX idx_deploy_history_release ON deploy_history (release_id);
CREATE INDEX idx_deploy_history_status ON deploy_history (status);
CREATE INDEX idx_deploy_history_started ON deploy_history (started_at DESC);
