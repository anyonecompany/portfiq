/**
 * Gemini 기반 뉴스 분류기 — 번역된 기사의 영향도, 감성,
 * 관련 섹터/티커를 분류한다.
 *
 * 번역 완료 + 미분류 기사를 대상으로 실행.
 */

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_MODEL = "gemini-2.0-flash-lite";
const MAX_ARTICLES = 20;

/**
 * Gemini API를 호출한다.
 */
async function callGemini(prompt: string): Promise<string | null> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return null;

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 2048,
          responseMimeType: "application/json",
        },
      }),
      signal: AbortSignal.timeout(20_000),
    });

    if (!response.ok) return null;
    const data = await response.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
  } catch {
    return null;
  }
}

/**
 * 분류 프롬프트를 생성한다.
 */
function buildClassificationPrompt(
  title: string,
  summary: string,
): string {
  return `당신은 ETF 투자 전문 분석가입니다. 다음 뉴스의 시장 영향을 분류하세요.

## 뉴스
제목: ${title}
요약: ${summary}

## 출력 (JSON)
{
  "impact_level": "high|medium|low|noise",
  "sentiment": "positive|negative|neutral",
  "confidence_score": 0.85,
  "sectors": ["기술", "에너지"],
  "affected_tickers": ["AAPL", "NVDA", "QQQ"],
  "reasoning": "분류 근거 1-2문장"
}

## 분류 기준
- high: 시장/섹터에 즉각적 영향. 실적 발표, 금리 결정, 대형 M&A, 정책 변화
- medium: 간접적 영향. 업종 전망, 경제지표, 애널리스트 의견
- low: 미미한 영향. 개별 종목 소식, 루머
- noise: 투자와 무관. 광고, 인사, 일반 기업 뉴스
- affected_tickers: 직접 영향받는 개별 종목 + 관련 ETF 티커 모두 포함
- sectors: 한국어 섹터명 (기술, 에너지, 헬스케어, 금융, 소비재, 산업재, 통신, 유틸리티, 부동산, 소재)`;
}

/**
 * 번역 완료 + 미분류 기사를 분류하여 news_classifications에 적재한다.
 *
 * @returns 분류 완료된 기사 수
 */
export async function classifyArticles(supabase: SupabaseClient): Promise<number> {
  // 번역 완료 + 미분류 기사 조회
  const { data: articles, error } = await supabase
    .from("news_articles")
    .select(`
      id,
      title,
      article_translations!inner (
        translated_title,
        translated_summary
      )
    `)
    .eq("is_translated", true)
    .eq("is_classified", false)
    .order("published_at", { ascending: false })
    .limit(MAX_ARTICLES);

  if (error) {
    console.error("[classifier] query error:", error.message);
    return 0;
  }

  if (!articles || articles.length === 0) {
    console.log("[classifier] no unclassified articles");
    return 0;
  }

  let classified = 0;

  for (const article of articles) {
    try {
      const translation = Array.isArray(article.article_translations)
        ? article.article_translations[0]
        : article.article_translations;

      if (!translation) continue;

      const prompt = buildClassificationPrompt(
        translation.translated_title,
        translation.translated_summary,
      );

      const rawResult = await callGemini(prompt);
      if (!rawResult) continue;

      let parsed;
      try {
        parsed = JSON.parse(rawResult);
      } catch {
        const jsonMatch = rawResult.match(/\{[\s\S]*\}/);
        if (jsonMatch) parsed = JSON.parse(jsonMatch[0]);
        else continue;
      }

      // noise는 저장하되 후속 처리에서 제외
      const { error: insertError } = await supabase
        .from("news_classifications")
        .upsert({
          article_id: article.id,
          impact_level: parsed.impact_level || "low",
          sentiment: parsed.sentiment || "neutral",
          confidence_score: parsed.confidence_score ?? 0.5,
          sectors: parsed.sectors || [],
          affected_tickers: parsed.affected_tickers || [],
          ai_reasoning: parsed.reasoning || "분류 근거 없음",
        }, { onConflict: "article_id" });

      if (insertError) {
        console.error(`[classifier] insert error for ${article.id}:`, insertError.message);
        continue;
      }

      await supabase
        .from("news_articles")
        .update({ is_classified: true })
        .eq("id", article.id);

      classified++;

      // Rate limit 방지
      await new Promise((r) => setTimeout(r, 500));
    } catch (e) {
      console.error(`[classifier] article ${article.id} failed:`, (e as Error).message);
    }
  }

  console.log(`[classifier] classified: ${classified}/${articles.length}`);
  return classified;
}
