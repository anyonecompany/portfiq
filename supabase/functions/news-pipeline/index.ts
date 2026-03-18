/**
 * Portfiq News Pipeline — Supabase Edge Function
 *
 * 30분마다 pg_cron으로 호출되어 다음을 순차 실행:
 * 1. RSS 수집 (Yahoo Finance, Seeking Alpha, Reuters)
 * 2. Gemini 번역 (영문 → 한국어, 금융 용어 사전 적용)
 * 3. Gemini 분류 (영향도, 감성, 섹터, 관련 티커)
 * 4. ETF 매칭 + 관심 ETF 유저에게만 시그널 피드 적재
 */

import "@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { collectNews } from "./collector.ts";
import { translateArticles } from "./translator.ts";
import { classifyArticles } from "./classifier.ts";
import { matchAndPersonalize } from "./matcher.ts";

Deno.serve(async (req) => {
  const startTime = Date.now();

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  if (!supabaseUrl || !supabaseKey) {
    return new Response(
      JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
  });

  try {
    // Step 1: RSS 수집
    console.log("[pipeline] Step 1: Collecting news...");
    const collected = await collectNews(supabase);

    // Step 2: 번역 (영문 기사만)
    console.log("[pipeline] Step 2: Translating articles...");
    const translated = await translateArticles(supabase);

    // Step 3: AI 분류
    console.log("[pipeline] Step 3: Classifying articles...");
    const classified = await classifyArticles(supabase);

    // Step 4: ETF 매칭 + 관심 ETF 유저에게만 적재
    console.log("[pipeline] Step 4: Matching & personalizing...");
    const matched = await matchAndPersonalize(supabase);

    const duration = Date.now() - startTime;

    const result = {
      collected,
      translated,
      classified,
      matched,
      duration_ms: duration,
      timestamp: new Date().toISOString(),
    };

    console.log("[pipeline] Complete:", JSON.stringify(result));

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    const duration = Date.now() - startTime;
    console.error("[pipeline] Fatal error:", (error as Error).message);

    return new Response(
      JSON.stringify({
        error: (error as Error).message,
        duration_ms: duration,
        timestamp: new Date().toISOString(),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
