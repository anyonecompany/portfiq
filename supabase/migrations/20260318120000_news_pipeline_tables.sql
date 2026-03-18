-- ──────────────────────────────────────────────
-- News Pipeline Tables (Edge Function용)
-- 기존 device_etfs 테이블을 관심 ETF로 활용
-- ──────────────────────────────────────────────

-- 1. 뉴스 기사 원문
CREATE TABLE IF NOT EXISTS news_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT,
    url TEXT UNIQUE NOT NULL,
    published_at TIMESTAMPTZ,
    language TEXT NOT NULL DEFAULT 'en'
        CHECK (language IN ('en', 'ko', 'ja')),
    raw_data JSONB,
    is_translated BOOLEAN DEFAULT false,
    is_classified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_news_articles_published
    ON news_articles (published_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_articles_translated
    ON news_articles (is_translated) WHERE NOT is_translated;
CREATE INDEX IF NOT EXISTS idx_news_articles_classified
    ON news_articles (is_classified) WHERE NOT is_classified;

-- 2. 번역 결과
CREATE TABLE IF NOT EXISTS article_translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID NOT NULL UNIQUE
        REFERENCES news_articles(id) ON DELETE CASCADE,
    translated_title TEXT NOT NULL,
    translated_content TEXT NOT NULL,
    translated_summary TEXT NOT NULL,
    key_terms JSONB NOT NULL DEFAULT '[]',
    translation_model TEXT DEFAULT 'gemini-3.1-flash-lite',
    quality_score FLOAT CHECK (quality_score BETWEEN 0 AND 1),
    translated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. AI 분류 결과
CREATE TABLE IF NOT EXISTS news_classifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID NOT NULL UNIQUE
        REFERENCES news_articles(id) ON DELETE CASCADE,
    impact_level TEXT CHECK (impact_level IN ('high', 'medium', 'low', 'noise')),
    sentiment TEXT CHECK (sentiment IN ('positive', 'negative', 'neutral')),
    confidence_score FLOAT CHECK (confidence_score BETWEEN 0 AND 1),
    sectors TEXT[],
    affected_tickers TEXT[],
    ai_reasoning TEXT NOT NULL,
    classified_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_news_classifications_impact
    ON news_classifications (impact_level, classified_at DESC);

-- 4. ETF 시그널 (기사 → ETF 매핑)
CREATE TABLE IF NOT EXISTS news_etf_signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    article_id UUID NOT NULL REFERENCES news_articles(id) ON DELETE CASCADE,
    classification_id UUID REFERENCES news_classifications(id) ON DELETE SET NULL,
    etf_code TEXT NOT NULL,
    etf_name TEXT NOT NULL,
    impact_direction TEXT CHECK (impact_direction IN ('positive', 'negative', 'neutral')),
    impact_magnitude FLOAT CHECK (impact_magnitude BETWEEN 0 AND 1),
    signal_text TEXT NOT NULL,
    is_synthesized BOOLEAN DEFAULT false,
    source_articles JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_news_etf_signals_etf
    ON news_etf_signals (etf_code, created_at DESC);

-- 5. 유저별 시그널 피드 (device_etfs 기반)
CREATE TABLE IF NOT EXISTS user_signal_feeds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id TEXT NOT NULL,
    signal_id UUID NOT NULL REFERENCES news_etf_signals(id) ON DELETE CASCADE,
    is_read BOOLEAN DEFAULT false,
    is_pushed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (device_id, signal_id)
);

CREATE INDEX IF NOT EXISTS idx_user_signal_feeds_device
    ON user_signal_feeds (device_id, is_read, created_at DESC);

-- 6. RLS 비활성화 (Edge Function은 service_role_key 사용)
ALTER TABLE news_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_classifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE news_etf_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_signal_feeds ENABLE ROW LEVEL SECURITY;

-- Service role은 모든 접근 허용
CREATE POLICY "service_role_all" ON news_articles
    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON article_translations
    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON news_classifications
    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON news_etf_signals
    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_all" ON user_signal_feeds
    FOR ALL USING (auth.role() = 'service_role');
