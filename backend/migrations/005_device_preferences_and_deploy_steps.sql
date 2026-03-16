-- ============================================================
-- Portfiq — Device Preferences & Deploy Step Metadata
-- Migration: 005_device_preferences_and_deploy_steps
-- Date: 2026-03-14
-- ============================================================

-- ──────────────────────────────────────────────
-- Device notification preferences
-- ──────────────────────────────────────────────
ALTER TABLE devices ADD COLUMN IF NOT EXISTS morning_briefing BOOLEAN DEFAULT TRUE;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS night_checkpoint BOOLEAN DEFAULT TRUE;
ALTER TABLE devices ADD COLUMN IF NOT EXISTS urgent_news BOOLEAN DEFAULT FALSE;

-- ──────────────────────────────────────────────
-- Deploy execution step metadata
-- ──────────────────────────────────────────────
ALTER TABLE deploy_history ADD COLUMN IF NOT EXISTS steps JSONB DEFAULT '[]'::jsonb;
