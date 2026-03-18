/**
 * RSS 수집기 — 해외 금융 뉴스 RSS 피드에서 기사를 수집하여
 * news_articles 테이블에 적재한다.
 *
 * 소스: Yahoo Finance, Seeking Alpha, Reuters, 한국경제, 네이버.
 * 중복 제거: URL UNIQUE 제약 (ON CONFLICT DO NOTHING).
 */

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/** RSS 피드 소스 정의 */
const RSS_FEEDS = [
  {
    name: "yahoo_finance",
    url: "https://finance.yahoo.com/news/rssindex",
    language: "en",
  },
  {
    name: "seeking_alpha",
    url: "https://seekingalpha.com/market_currents.xml",
    language: "en",
  },
  {
    name: "reuters",
    url: "https://www.reutersagency.com/feed/?taxonomy=best-sectors&post_type=best",
    language: "en",
  },
];

/** ETF/금융 관련 키워드 필터 */
const FINANCE_KEYWORDS = [
  "etf", "fund", "stock", "market", "index", "s&p", "nasdaq", "dow",
  "earnings", "fed", "rate", "inflation", "gdp", "treasury",
  "semiconductor", "tech", "energy", "healthcare", "finance",
  "dividend", "bond", "yield", "crypto", "bitcoin",
  "apple", "nvidia", "tesla", "microsoft", "amazon", "google",
  "ai", "chip", "tariff", "trade", "oil", "gold",
];

interface RssItem {
  title: string;
  link: string;
  pubDate?: string;
  description?: string;
}

/**
 * XML에서 RSS 아이템을 파싱한다 (경량 파서).
 */
function parseRssItems(xml: string): RssItem[] {
  const items: RssItem[] = [];
  const itemRegex = /<item>([\s\S]*?)<\/item>/gi;
  let match;

  while ((match = itemRegex.exec(xml)) !== null) {
    const block = match[1];
    const title = block.match(/<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/title>/)?.[1] ?? "";
    const link = block.match(/<link>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?<\/link>/)?.[1] ?? "";
    const pubDate = block.match(/<pubDate>(.*?)<\/pubDate>/)?.[1];
    const description = block.match(/<description>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?<\/description>/)?.[1];

    if (title && link) {
      items.push({
        title: title.trim(),
        link: link.trim(),
        pubDate: pubDate?.trim(),
        description: description?.trim(),
      });
    }
  }
  return items;
}

/**
 * 기사가 금융/ETF 관련인지 키워드 필터링한다.
 */
function isFinanceRelated(title: string, description?: string): boolean {
  const text = `${title} ${description ?? ""}`.toLowerCase();
  return FINANCE_KEYWORDS.some((kw) => text.includes(kw));
}

/**
 * RSS 피드를 수집하여 news_articles에 적재한다.
 *
 * @returns 신규 수집된 기사 수
 */
export async function collectNews(supabase: SupabaseClient): Promise<number> {
  let totalCollected = 0;

  for (const feed of RSS_FEEDS) {
    try {
      const response = await fetch(feed.url, {
        headers: { "User-Agent": "Portfiq/1.0 NewsBot" },
        signal: AbortSignal.timeout(10_000),
      });

      if (!response.ok) {
        console.warn(`[collector] ${feed.name} HTTP ${response.status}`);
        continue;
      }

      const xml = await response.text();
      const items = parseRssItems(xml);

      const articles = items
        .filter((item) => isFinanceRelated(item.title, item.description))
        .slice(0, 30) // 피드당 최대 30건
        .map((item) => ({
          source: feed.name,
          title: item.title,
          content: item.description ?? null,
          url: item.link,
          published_at: item.pubDate ? new Date(item.pubDate).toISOString() : null,
          language: feed.language,
          raw_data: { feed: feed.name },
          is_translated: false,
          is_classified: false,
        }));

      if (articles.length === 0) continue;

      // INSERT ON CONFLICT DO NOTHING (URL 중복 무시)
      const { data, error } = await supabase
        .from("news_articles")
        .upsert(articles, { onConflict: "url", ignoreDuplicates: true })
        .select("id");

      if (error) {
        console.error(`[collector] ${feed.name} insert error:`, error.message);
        continue;
      }

      const count = data?.length ?? 0;
      totalCollected += count;
      console.log(`[collector] ${feed.name}: ${count} new articles`);
    } catch (e) {
      console.error(`[collector] ${feed.name} fetch failed:`, (e as Error).message);
    }
  }

  console.log(`[collector] total collected: ${totalCollected}`);
  return totalCollected;
}
