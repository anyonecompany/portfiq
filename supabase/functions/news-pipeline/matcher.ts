/**
 * ETF 매칭 + 관심 ETF 기반 개인화 필터.
 *
 * 분류 결과(affected_tickers, sectors)를 etf_master의 holdings와 매칭하여
 * news_etf_signals를 생성한다.
 *
 * ★ 핵심: device_etfs 테이블에 등록된 관심 ETF와 매칭되는 시그널만
 *   user_signal_feeds에 적재 → 관심 없는 ETF 시그널은 피드에 안 감.
 */

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

interface EtfMaster {
  ticker: string;
  name: string;
  name_kr?: string;
  category?: string;
  top_holdings?: string[]; // PostgreSQL text[] — ticker 배열
}

interface Classification {
  id: string;
  article_id: string;
  impact_level: string;
  sentiment: string;
  sectors: string[];
  affected_tickers: string[];
  ai_reasoning: string;
}

/** 섹터 → ETF 카테고리 매핑 */
const SECTOR_CATEGORY_MAP: Record<string, string[]> = {
  "기술": ["기술주", "반도체", "AI/로봇", "클라우드"],
  "에너지": ["에너지", "클린에너지", "원유"],
  "헬스케어": ["헬스케어", "바이오"],
  "금융": ["금융", "핀테크"],
  "소비재": ["소비재", "리테일"],
  "산업재": ["산업재", "우주항공"],
  "부동산": ["부동산", "리츠"],
  "소재": ["소재", "광업", "금"],
};

/**
 * 분류 결과를 ETF에 매칭한다.
 *
 * 매칭 우선순위:
 * 1. affected_tickers가 ETF 자체 ticker인 경우 (직접 매칭)
 * 2. affected_tickers가 ETF의 top_holdings에 포함된 경우 (구성종목 매칭)
 * 3. sectors가 ETF category와 매칭되는 경우 (섹터 매칭)
 */
function findMatchingEtfs(
  classification: Classification,
  etfList: EtfMaster[],
): Array<{ ticker: string; name: string; matchType: string; magnitude: number }> {
  const matches: Array<{ ticker: string; name: string; matchType: string; magnitude: number }> = [];
  const affectedSet = new Set(classification.affected_tickers.map((t) => t.toUpperCase()));

  for (const etf of etfList) {
    const etfTicker = etf.ticker.toUpperCase();

    // 1. 직접 매칭: ETF 티커가 affected_tickers에 있음
    if (affectedSet.has(etfTicker)) {
      matches.push({
        ticker: etf.ticker,
        name: etf.name_kr || etf.name,
        matchType: "direct",
        magnitude: 0.9,
      });
      continue;
    }

    // 2. 구성종목 매칭: affected_tickers가 ETF holdings에 포함
    const holdings = etf.top_holdings ?? [];
    const holdingMatch = holdings.some((h) => affectedSet.has(h.toUpperCase()));
    if (holdingMatch) {
      matches.push({
        ticker: etf.ticker,
        name: etf.name_kr || etf.name,
        matchType: "holdings",
        magnitude: 0.6,
      });
      continue;
    }

    // 3. 섹터 매칭
    const etfCategory = etf.category?.toLowerCase() ?? "";
    for (const sector of classification.sectors) {
      const categories = SECTOR_CATEGORY_MAP[sector] ?? [];
      if (categories.some((cat) => etfCategory.includes(cat.toLowerCase()))) {
        matches.push({
          ticker: etf.ticker,
          name: etf.name_kr || etf.name,
          matchType: "sector",
          magnitude: 0.3,
        });
        break;
      }
    }
  }

  return matches;
}

/**
 * ETF 매칭 + 관심 ETF 유저에게 시그널 피드를 적재한다.
 *
 * @returns 생성된 시그널 수
 */
export async function matchAndPersonalize(supabase: SupabaseClient): Promise<number> {
  // 1. 분류 완료 + 아직 매칭 안 된 기사 조회 (noise 제외)
  const { data: classifications, error: clsError } = await supabase
    .from("news_classifications")
    .select(`
      id,
      article_id,
      impact_level,
      sentiment,
      sectors,
      affected_tickers,
      ai_reasoning
    `)
    .neq("impact_level", "noise")
    .order("classified_at", { ascending: false })
    .limit(50);

  if (clsError || !classifications?.length) {
    console.log("[matcher] no classifications to process");
    return 0;
  }

  // 이미 시그널이 생성된 article_id 조회
  const articleIds = classifications.map((c) => c.article_id);
  const { data: existingSignals } = await supabase
    .from("news_etf_signals")
    .select("article_id")
    .in("article_id", articleIds);

  const existingArticleIds = new Set(
    (existingSignals ?? []).map((s) => s.article_id),
  );

  // 미처리 분류만 필터
  const unmatched = classifications.filter(
    (c) => !existingArticleIds.has(c.article_id),
  );

  if (unmatched.length === 0) {
    console.log("[matcher] all classifications already matched");
    return 0;
  }

  // 2. etf_master에서 ETF 목록 로드
  const { data: etfMasterData, error: etfError } = await supabase
    .from("etf_master")
    .select("ticker, name, category, top_holdings")
    .eq("is_active", true);

  if (etfError || !etfMasterData?.length) {
    console.error("[matcher] etf_master query failed:", etfError?.message);
    return 0;
  }

  // 3. 전체 device_etfs 로드 (관심 ETF 매핑용)
  const { data: deviceEtfs } = await supabase
    .from("device_etfs")
    .select("device_id, ticker");

  // ticker → device_id[] 매핑
  const tickerToDevices = new Map<string, string[]>();
  for (const de of deviceEtfs ?? []) {
    const existing = tickerToDevices.get(de.ticker.toUpperCase()) ?? [];
    existing.push(de.device_id);
    tickerToDevices.set(de.ticker.toUpperCase(), existing);
  }

  let signalCount = 0;

  // 4. 매칭 실행
  for (const cls of unmatched) {
    const matchedEtfs = findMatchingEtfs(cls, etfMasterData);

    for (const etf of matchedEtfs) {
      // news_etf_signals INSERT
      const sentimentMap: Record<string, string> = {
        positive: "positive",
        negative: "negative",
        neutral: "neutral",
      };

      const { data: signalData, error: signalError } = await supabase
        .from("news_etf_signals")
        .insert({
          article_id: cls.article_id,
          classification_id: cls.id,
          etf_code: etf.ticker,
          etf_name: etf.name,
          impact_direction: sentimentMap[cls.sentiment] ?? "neutral",
          impact_magnitude: etf.magnitude,
          signal_text: cls.ai_reasoning,
        })
        .select("id")
        .single();

      if (signalError || !signalData) {
        console.warn(`[matcher] signal insert failed for ${etf.ticker}:`, signalError?.message);
        continue;
      }

      signalCount++;

      // ★ 핵심: 이 ETF를 관심 등록한 디바이스에게만 피드 적재
      const watchingDevices = tickerToDevices.get(etf.ticker.toUpperCase()) ?? [];

      if (watchingDevices.length === 0) continue;

      const feedRows = watchingDevices.map((deviceId) => ({
        device_id: deviceId,
        signal_id: signalData.id,
        is_read: false,
        is_pushed: cls.impact_level === "high",
      }));

      const { error: feedError } = await supabase
        .from("user_signal_feeds")
        .upsert(feedRows, { onConflict: "device_id,signal_id", ignoreDuplicates: true });

      if (feedError) {
        console.warn(`[matcher] feed insert failed:`, feedError.message);
      }
    }
  }

  console.log(`[matcher] signals created: ${signalCount}`);
  return signalCount;
}
