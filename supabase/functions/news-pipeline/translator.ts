/**
 * Gemini 기반 금융 뉴스 번역기 — 영문 기사를 한국 투자자 관점의
 * 자연스러운 한국어로 번역한다.
 *
 * 금융 용어 사전(glossary)을 프롬프트에 주입하여 일관된 번역 품질을 보장.
 * 배치 처리: 미번역 기사를 5건씩 묶어 순차 번역.
 */

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { glossaryToPromptBlock } from "./glossary.ts";

const GEMINI_MODEL = "gemini-2.0-flash-lite";
const BATCH_SIZE = 5;
const MAX_ARTICLES = 20; // 1회 실행당 최대 번역 수

/**
 * Gemini API를 호출하여 번역 결과를 반환한다.
 */
async function callGemini(prompt: string): Promise<string | null> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    console.error("[translator] GEMINI_API_KEY not set");
    return null;
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 4096,
          responseMimeType: "application/json",
        },
      }),
      signal: AbortSignal.timeout(30_000),
    });

    if (!response.ok) {
      const errText = await response.text();
      if (response.status === 429) {
        console.warn(`[translator] Gemini rate limited, waiting 35s...`);
        await new Promise((r) => setTimeout(r, 35_000));
        // 1회 재시도
        const retry = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { temperature: 0.1, maxOutputTokens: 4096, responseMimeType: "application/json" },
          }),
          signal: AbortSignal.timeout(30_000),
        });
        if (!retry.ok) {
          console.error(`[translator] Gemini retry failed: ${retry.status}`);
          return null;
        }
        const retryData = await retry.json();
        return retryData.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
      }
      console.error(`[translator] Gemini ${response.status}: ${errText.slice(0, 200)}`);
      return null;
    }

    const data = await response.json();
    return data.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
  } catch (e) {
    console.error("[translator] Gemini call failed:", (e as Error).message);
    return null;
  }
}

/**
 * 번역 프롬프트를 생성한다.
 */
function buildTranslationPrompt(title: string, content: string): string {
  const glossary = glossaryToPromptBlock();

  return `당신은 금융 전문 번역가입니다. 해외 ETF/금융 뉴스를 한국 개인투자자가
이해하기 쉬운 자연스러운 한국어로 번역합니다.

## 번역 원칙
- 금융 용어는 아래 사전을 따르세요. 사전에 없는 용어는 "영문(한글)" 형태.
- 수치/통화 원문 유지 ($3.2B, 2.4%)
- 기업명 원문 유지 (Apple, TSMC)
- 번역투 피하고 자연스러운 한국어
- 약어 처음 등장 시 풀어서: "CPI(소비자물가지수)"

## 용어 사전
${glossary}

## 번역 대상
제목: ${title}
본문: ${content || "(본문 없음)"}

## 출력 (JSON)
{
  "translated_title": "번역된 제목",
  "translated_content": "번역된 본문 (본문 없으면 제목 기반 1-2문장 요약)",
  "translated_summary": "3줄 핵심 요약 (한국 투자자 관점, 각 줄은 • 로 시작)",
  "key_terms": [
    {"original": "영문", "translated": "한글", "explanation": "초보자 설명"}
  ],
  "quality_self_score": 0.85
}`;
}

/**
 * 미번역 영문 기사를 번역하여 article_translations에 적재한다.
 *
 * @returns 번역 완료된 기사 수
 */
export async function translateArticles(supabase: SupabaseClient): Promise<number> {
  // 미번역 영문 기사 조회
  const { data: articles, error } = await supabase
    .from("news_articles")
    .select("id, title, content, language")
    .eq("is_translated", false)
    .eq("language", "en")
    .order("published_at", { ascending: false })
    .limit(MAX_ARTICLES);

  if (error) {
    console.error("[translator] query error:", error.message);
    return 0;
  }

  if (!articles || articles.length === 0) {
    console.log("[translator] no untranslated articles");
    return 0;
  }

  let translated = 0;

  // 배치 처리
  for (let i = 0; i < articles.length; i += BATCH_SIZE) {
    const batch = articles.slice(i, i + BATCH_SIZE);

    for (const article of batch) {
      try {
        const prompt = buildTranslationPrompt(article.title, article.content ?? "");
        const rawResult = await callGemini(prompt);

        if (!rawResult) {
          console.warn(`[translator] skip ${article.id}: no Gemini response`);
          continue;
        }

        let parsed;
        try {
          parsed = JSON.parse(rawResult);
        } catch {
          // JSON 코드블록 안에 있을 수 있음
          const jsonMatch = rawResult.match(/\{[\s\S]*\}/);
          if (jsonMatch) {
            parsed = JSON.parse(jsonMatch[0]);
          } else {
            console.warn(`[translator] skip ${article.id}: invalid JSON`);
            continue;
          }
        }

        // article_translations에 INSERT
        const { error: insertError } = await supabase
          .from("article_translations")
          .upsert({
            article_id: article.id,
            translated_title: parsed.translated_title || article.title,
            translated_content: parsed.translated_content || "",
            translated_summary: parsed.translated_summary || "",
            key_terms: parsed.key_terms || [],
            translation_model: GEMINI_MODEL,
            quality_score: parsed.quality_self_score ?? null,
          }, { onConflict: "article_id" });

        if (insertError) {
          console.error(`[translator] insert error for ${article.id}:`, insertError.message);
          continue;
        }

        // news_articles.is_translated = true
        await supabase
          .from("news_articles")
          .update({ is_translated: true })
          .eq("id", article.id);

        translated++;
      } catch (e) {
        console.error(`[translator] article ${article.id} failed:`, (e as Error).message);
      }
    }

    // 배치 간 1.5초 대기 (rate limit 방지)
    if (i + BATCH_SIZE < articles.length) {
      await new Promise((r) => setTimeout(r, 1500));
    }
  }

  console.log(`[translator] translated: ${translated}/${articles.length}`);
  return translated;
}
