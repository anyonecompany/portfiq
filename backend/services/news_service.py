"""News aggregation service — real-time RSS with background translation.

Architecture:
  1. RSS 수집 → 즉시 캐시에 영문 원문 저장 (latency: ~3초)
  2. 번역은 별도 백그라운드 태스크로 비동기 처리
  3. 번역 완료 시 캐시 업데이트 (영문 → 한국어)
  4. API 응답은 항상 캐시에서 즉시 반환 (번역 대기 없음)
"""

from __future__ import annotations

import asyncio
import json
import logging
import threading
from datetime import datetime, timedelta, timezone
from typing import Any

import anthropic
import feedparser
import httpx

from config import settings
from models.schemas import FeedItem, ETFImpact
from prompts.translate import TRANSLATE_PROMPT

logger = logging.getLogger(__name__)

_TRANSLATE_MODEL = "claude-sonnet-4-5-20250929"
_translate_client: anthropic.Anthropic | None = None


def _get_translate_client() -> anthropic.Anthropic:
    """Return a lazily-initialised Anthropic client for translation."""
    global _translate_client
    if _translate_client is None:
        _translate_client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _translate_client


# ──────────────────────────────────────────────
# RSS feeds — US financial news (primary)
# ──────────────────────────────────────────────

RSS_FEEDS_EN: list[tuple[str, str]] = [
    ("https://finance.yahoo.com/news/rssindex", "Yahoo Finance"),
    ("https://feeds.marketwatch.com/marketwatch/topstories", "MarketWatch"),
    ("https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=10001147", "CNBC"),
    ("https://www.investing.com/rss/news.rss", "Investing.com"),
    ("https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=20910258", "CNBC ETF"),
    ("https://feeds.marketwatch.com/marketwatch/marketpulse", "MarketWatch Pulse"),
    ("https://feeds.bloomberg.com/markets/news.rss", "Bloomberg Markets"),
    ("https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=10000664", "CNBC Tech"),
    ("https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=19836768", "CNBC Earnings"),
    ("https://feeds.reuters.com/reuters/businessNews", "Reuters Business"),
]

RSS_FEEDS_KR: list[tuple[str, str]] = []
RSS_FEEDS = [url for url, _ in RSS_FEEDS_EN]

# ──────────────────────────────────────────────
# Real-time news cache
# ──────────────────────────────────────────────

_news_cache: list[dict] = []
_translation_lock = threading.Lock()
_translating = False  # True while background translation is running

# ──────────────────────────────────────────────
# Mock news items (10 realistic Korean-language items)
# Timestamps use dynamic offsets so they always appear fresh.
# ──────────────────────────────────────────────


def _mock_ts(hours_ago: float) -> str:
    """Return an ISO-8601 UTC timestamp *hours_ago* before now."""
    return (datetime.now(timezone.utc) - timedelta(hours=hours_ago)).isoformat()


def _build_mock_news() -> list[FeedItem]:
    """Build mock news with dynamic relative timestamps."""
    return [
        FeedItem(
            id="news-001",
            headline="FOMC 금리 동결 결정, 시장 안도 랠리 예상",
            impact_reason=(
                "연준이 기준금리를 5.25~5.50%에서 동결했습니다.\n"
                "파월 의장은 연내 인하 가능성을 시사하며 시장에 긍정적 신호를 보냈습니다.\n"
                "기술주 중심의 QQQ와 대형주 중심의 VOO에 상승 모멘텀이 예상됩니다."
            ),
            source="Reuters",
            source_url="https://reuters.com/markets/fomc-2026",
            published_at=_mock_ts(1),
            impacts=[
                ETFImpact(etf_ticker="QQQ", level="High"),
                ETFImpact(etf_ticker="VOO", level="High"),
                ETFImpact(etf_ticker="SPY", level="High"),
                ETFImpact(etf_ticker="TLT", level="Medium"),
            ],
        ),
        FeedItem(
            id="news-002",
            headline="NVIDIA 분기 실적 발표, 매출 260% 급증",
            impact_reason=(
                "NVIDIA가 AI 칩 수요 폭증에 힘입어 분기 매출 $26B을 기록했습니다.\n"
                "데이터센터 부문이 전체 매출의 78%를 차지하며 기대치를 상회했습니다.\n"
                "반도체 ETF(SOXL, SOXX)와 기술주 ETF(QQQ)에 즉각적 상승 압력이 예상됩니다."
            ),
            source="Bloomberg",
            source_url="https://bloomberg.com/nvidia-earnings-2026",
            published_at=_mock_ts(3),
            impacts=[
                ETFImpact(etf_ticker="SOXL", level="High"),
                ETFImpact(etf_ticker="QQQ", level="High"),
                ETFImpact(etf_ticker="SOXX", level="High"),
                ETFImpact(etf_ticker="SMH", level="High"),
            ],
        ),
        FeedItem(
            id="news-003",
            headline="SCHD 분기 배당 $0.72 발표, 전년 대비 8% 증가",
            impact_reason=(
                "SCHD가 분기당 $0.72 배당을 확정하며 배당 성장세를 이어갔습니다.\n"
                "연간 배당수익률은 약 3.8%로, 인컴 투자자들에게 매력적입니다.\n"
                "배당주 중심 포트폴리오 재편 수요가 증가할 수 있습니다."
            ),
            source="Seeking Alpha",
            source_url="https://seekingalpha.com/schd-dividend-2026",
            published_at=_mock_ts(5),
            impacts=[
                ETFImpact(etf_ticker="SCHD", level="High"),
                ETFImpact(etf_ticker="JEPI", level="Medium"),
            ],
        ),
        FeedItem(
            id="news-004",
            headline="ARK Invest, Tesla 목표가 $350 유지하며 추가 매수",
            impact_reason=(
                "캐시 우드가 이끄는 ARK Invest가 Tesla 주식을 5일 연속 매수했습니다.\n"
                "자율주행 FSD V13 출시 기대감이 핵심 근거로 제시되었습니다.\n"
                "ARKK ETF 내 Tesla 비중이 12%로 확대되며 변동성이 커질 수 있습니다."
            ),
            source="CNBC",
            source_url="https://cnbc.com/ark-tesla-2026",
            published_at=_mock_ts(7),
            impacts=[
                ETFImpact(etf_ticker="ARKK", level="High"),
                ETFImpact(etf_ticker="QQQ", level="Low"),
            ],
        ),
        FeedItem(
            id="news-005",
            headline="국제유가 WTI $85 돌파, OPEC+ 감산 연장 영향",
            impact_reason=(
                "OPEC+가 2분기까지 일일 200만 배럴 감산을 연장하기로 합의했습니다.\n"
                "WTI 유가가 $85를 넘기며 에너지 섹터 전반에 호재로 작용합니다.\n"
                "에너지 ETF(XLE)의 상승과 함께 소비재 비용 부담으로 인한 VOO 하방 리스크도 존재합니다."
            ),
            source="Financial Times",
            source_url="https://ft.com/oil-price-opec-2026",
            published_at=_mock_ts(9),
            impacts=[
                ETFImpact(etf_ticker="XLE", level="High"),
                ETFImpact(etf_ticker="VOO", level="Medium"),
                ETFImpact(etf_ticker="SPY", level="Low"),
            ],
        ),
        FeedItem(
            id="news-006",
            headline="미 국채 10년물 금리 4.1%로 하락, 채권 랠리 시작",
            impact_reason=(
                "경기 둔화 우려로 미 국채 10년물 금리가 4.1%까지 떨어졌습니다.\n"
                "금리 하락은 장기 채권 가격 상승으로 이어져 TLT에 강한 호재입니다.\n"
                "동시에 금리 민감 성장주(QQQ, ARKK)에도 긍정적 영향을 줍니다."
            ),
            source="WSJ",
            source_url="https://wsj.com/treasury-yield-2026",
            published_at=_mock_ts(11),
            impacts=[
                ETFImpact(etf_ticker="TLT", level="High"),
                ETFImpact(etf_ticker="QQQ", level="Medium"),
                ETFImpact(etf_ticker="ARKK", level="Medium"),
            ],
        ),
        FeedItem(
            id="news-007",
            headline="골드만삭스, 2026년 S&P 500 목표치 6,200 제시",
            impact_reason=(
                "골드만삭스가 S&P 500 연말 목표치를 기존 5,800에서 6,200으로 상향했습니다.\n"
                "AI 생산성 향상과 기업 실적 개선이 핵심 근거입니다.\n"
                "S&P 500 추종 ETF(SPY, VOO, IVV) 모두에 긍정적 시그널입니다."
            ),
            source="Goldman Sachs Research",
            source_url="https://goldmansachs.com/outlook-2026",
            published_at=_mock_ts(13),
            impacts=[
                ETFImpact(etf_ticker="SPY", level="Medium"),
                ETFImpact(etf_ticker="VOO", level="Medium"),
                ETFImpact(etf_ticker="IVV", level="Medium"),
                ETFImpact(etf_ticker="VTI", level="Low"),
            ],
        ),
        FeedItem(
            id="news-008",
            headline="중국 AI 스타트업 DeepSeek, 미국 반도체 수입 규제 우회 논란",
            impact_reason=(
                "DeepSeek가 미국 반도체 수출 규제를 우회해 고성능 칩을 확보했다는 보도가 나왔습니다.\n"
                "미-중 기술 갈등 심화는 중국 인터넷 ETF(KWEB)에 하방 리스크를 높입니다.\n"
                "반면 미국 반도체 기업 보호 정책 강화로 SOXL에는 복합적 영향이 예상됩니다."
            ),
            source="South China Morning Post",
            source_url="https://scmp.com/deepseek-chips-2026",
            published_at=_mock_ts(15),
            impacts=[
                ETFImpact(etf_ticker="KWEB", level="High"),
                ETFImpact(etf_ticker="SOXL", level="Medium"),
                ETFImpact(etf_ticker="EEM", level="Medium"),
            ],
        ),
        FeedItem(
            id="news-009",
            headline="금값 사상 최고 $2,400 돌파, 안전자산 선호 강화",
            impact_reason=(
                "지정학적 리스크와 달러 약세로 금 가격이 사상 최고치를 경신했습니다.\n"
                "중앙은행 금 매수세가 지속되며 GLD ETF로의 자금 유입이 가속화되고 있습니다.\n"
                "안전자산 선호가 강해지면 성장주 ETF에서 자금 이탈이 나타날 수 있습니다."
            ),
            source="MarketWatch",
            source_url="https://marketwatch.com/gold-record-2026",
            published_at=_mock_ts(17),
            impacts=[
                ETFImpact(etf_ticker="GLD", level="High"),
                ETFImpact(etf_ticker="QQQ", level="Low"),
                ETFImpact(etf_ticker="ARKK", level="Low"),
            ],
        ),
        FeedItem(
            id="news-010",
            headline="JP모건, JEPI 운용자산 $40B 돌파 발표",
            impact_reason=(
                "JEPI가 출시 4년 만에 운용자산 $40B을 돌파하며 인컴 ETF 시장 1위를 굳혔습니다.\n"
                "커버드콜 전략의 안정적 수익 제공이 인기 요인으로 분석됩니다.\n"
                "배당 투자 트렌드 지속으로 SCHD와 함께 자금 유입이 이어질 전망입니다."
            ),
            source="ETF.com",
            source_url="https://etf.com/jepi-40b-2026",
            published_at=_mock_ts(20),
            impacts=[
                ETFImpact(etf_ticker="JEPI", level="High"),
                ETFImpact(etf_ticker="SCHD", level="Medium"),
            ],
        ),
    ]


# ──────────────────────────────────────────────
# Translation / summarisation helpers
# ──────────────────────────────────────────────

_TRANSLATE_SUMMARISE_PROMPT = """아래 영문 뉴스 헤드라인들을 한국어로 번역하고, 각 헤드라인에 대해 3줄 요약과 투자 심리 평가를 생성하세요.

{headlines}

JSON 배열로 응답하세요:
[
  {{"index": 0, "ko": "한국어 번역 헤드라인", "impact_reason": "줄1\\n줄2\\n줄3", "summary_3line": "• 핵심 사실 한 줄\\n• 시장 영향 한 줄\\n• 투자자 액션 한 줄", "sentiment": "호재"}},
  ...
]

규칙:
- 금융/투자 용어는 한국 투자자에게 익숙한 표현 사용
- 헤드라인은 간결하게 번역 (원문보다 짧게)
- 헤드라인에 이모지 사용 금지 (순수 한국어 텍스트만)
- impact_reason은 반드시 3줄: (1) 사실 요약 (2) 시장 영향 분석 (3) 관련 ETF 영향
- summary_3line은 반드시 3줄 (• 로 시작, \\n으로 구분): (1) 핵심 사실 (2) 시장에 미치는 영향 (3) 투자자가 취해야 할 행동이나 주의점
- sentiment는 반드시 "호재", "중립", "위험" 중 하나:
  - 호재: 주가 상승/긍정적 영향이 예상되는 뉴스
  - 중립: 방향성이 불명확하거나 영향이 제한적인 뉴스
  - 위험: 주가 하락/부정적 영향이 예상되는 뉴스
- \\n으로 줄 구분
"""


_BATCH_SIZE = 10  # 한 번에 번역할 헤드라인 수 (summary_3line+sentiment 추가로 출력 증가)


async def _translate_batch(headlines: list[str]) -> list[dict[str, str]]:
    """Translate a single batch of headlines (max ~15).

    Returns list of dicts with 'ko' and 'impact_reason' keys.
    """
    fallback = [{"ko": h, "impact_reason": ""} for h in headlines]

    numbered = "\n".join(f"[{i}] {h}" for i, h in enumerate(headlines))
    prompt = _TRANSLATE_SUMMARISE_PROMPT.format(headlines=numbered)

    try:
        client = _get_translate_client()
        response = client.messages.create(
            model=_TRANSLATE_MODEL,
            max_tokens=8192,
            messages=[{"role": "user", "content": prompt}],
        )
        text = response.content[0].text
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]

        parsed: list[dict] = json.loads(text.strip())

        result_map: dict[int, dict[str, str]] = {}
        for item in parsed:
            idx = item.get("index", -1)
            ko = item.get("ko", "")
            reason = item.get("impact_reason", "")
            if 0 <= idx < len(headlines) and ko:
                result_map[idx] = {
                    "ko": ko,
                    "impact_reason": reason,
                    "summary_3line": item.get("summary_3line", ""),
                    "sentiment": item.get("sentiment", "중립"),
                }

        return [
            result_map.get(i, {"ko": h, "impact_reason": "", "summary_3line": "", "sentiment": "중립"})
            for i, h in enumerate(headlines)
        ]

    except Exception as e:
        logger.error("번역 배치 실패: %s", e)
        return fallback


async def _translate_and_summarize(headlines: list[str]) -> list[dict[str, str]]:
    """Translate English headlines to Korean AND generate impact_reason.

    Processes in batches of _BATCH_SIZE to avoid token limits.

    Args:
        headlines: List of English headline strings.

    Returns:
        List of dicts with 'ko' (translated headline) and 'impact_reason' keys.
    """
    if not headlines:
        return []

    if not settings.ANTHROPIC_API_KEY:
        logger.warning("ANTHROPIC_API_KEY 미설정 — 원문 헤드라인 반환")
        return [{"ko": h, "impact_reason": ""} for h in headlines]

    results: list[dict[str, str]] = []
    for start in range(0, len(headlines), _BATCH_SIZE):
        batch = headlines[start:start + _BATCH_SIZE]
        logger.info("번역 배치 %d~%d / %d", start, start + len(batch), len(headlines))
        translated = await _translate_batch(batch)
        results.extend(translated)

    return results


# ──────────────────────────────────────────────
# RSS collection
# ──────────────────────────────────────────────

async def _collect_rss_fast() -> list[dict]:
    """Collect RSS articles WITHOUT translation (fast, ~3 seconds).

    Returns immediately with English headlines. Translation happens later
    in background via _translate_cached_articles().
    """
    articles: list[dict] = []

    async with httpx.AsyncClient(timeout=10.0) as client:
        for feed_url, source_name in RSS_FEEDS_EN:
            try:
                resp = await client.get(feed_url, headers={
                    "User-Agent": "Mozilla/5.0 (compatible; Portfiq/1.0)"
                })
                resp.raise_for_status()
                feed = feedparser.parse(resp.text)

                for entry in feed.entries[:10]:
                    published = entry.get("published_parsed")
                    pub_dt = (
                        datetime(*published[:6], tzinfo=timezone.utc)
                        if published
                        else datetime.now(timezone.utc)
                    )

                    articles.append({
                        "headline_en": entry.get("title", ""),
                        "headline": entry.get("title", ""),  # English until translated
                        "summary": entry.get("summary", ""),
                        "source": source_name,
                        "source_url": entry.get("link", ""),
                        "published_at": pub_dt.isoformat(),
                        "translated": False,
                    })
            except Exception as e:
                logger.warning("RSS 수집 실패 (%s): %s", feed_url, e)

    return articles


def _translate_cached_articles_sync() -> None:
    """Translate cached articles in background thread.

    Runs in a separate thread so API responses are never blocked.
    """
    global _news_cache, _translating

    with _translation_lock:
        if _translating:
            return
        _translating = True

    try:
        untranslated = [a for a in _news_cache if not a.get("translated")]
        if not untranslated:
            return

        if not settings.ANTHROPIC_API_KEY:
            logger.warning("ANTHROPIC_API_KEY 미설정 — 번역 건너뜀")
            return

        headlines = [a["headline_en"] for a in untranslated]
        logger.info("백그라운드 번역 시작: %d건", len(headlines))

        # Synchronous batch translation
        for start in range(0, len(headlines), _BATCH_SIZE):
            batch = headlines[start:start + _BATCH_SIZE]
            numbered = "\n".join(f"[{i}] {h}" for i, h in enumerate(batch))
            prompt = _TRANSLATE_SUMMARISE_PROMPT.format(headlines=numbered)

            try:
                client = _get_translate_client()
                response = client.messages.create(
                    model=_TRANSLATE_MODEL,
                    max_tokens=8192,
                    messages=[{"role": "user", "content": prompt}],
                )
                text = response.content[0].text
                if "```json" in text:
                    text = text.split("```json")[1].split("```")[0]
                elif "```" in text:
                    text = text.split("```")[1].split("```")[0]

                parsed: list[dict] = json.loads(text.strip())
                result_map: dict[int, dict] = {}
                for item in parsed:
                    idx = item.get("index", -1)
                    if 0 <= idx < len(batch) and item.get("ko"):
                        result_map[idx] = item

                # Update cache in-place
                for i, article in enumerate(untranslated[start:start + len(batch)]):
                    tr = result_map.get(i)
                    if tr:
                        article["headline"] = tr["ko"]
                        if tr.get("impact_reason"):
                            article["summary"] = tr["impact_reason"]
                        article["summary_3line"] = tr.get("summary_3line", "")
                        article["sentiment"] = tr.get("sentiment", "중립")
                        article["translated"] = True

                logger.info("번역 배치 완료: %d~%d / %d", start, start + len(batch), len(headlines))

            except Exception as e:
                logger.error("번역 배치 실패 (%d~%d): %s", start, start + len(batch), e)

        translated_count = sum(1 for a in _news_cache if a.get("translated"))
        logger.info("백그라운드 번역 완료: %d / %d건", translated_count, len(_news_cache))

    finally:
        with _translation_lock:
            _translating = False


async def fetch_rss_news() -> list[dict]:
    """Collect RSS news WITHOUT translation (fast).

    Returns articles with English headlines.
    Translation is started by fetch_and_store_news() after cache update.
    """
    return await _collect_rss_fast()


def _deduplicate(articles: list[dict]) -> list[dict]:
    """source_url 기준 중복 제거."""
    seen: set[str] = set()
    unique: list[dict] = []
    for a in articles:
        url = a.get("source_url", "")
        if url and url not in seen:
            seen.add(url)
            unique.append(a)
    return unique


async def fetch_and_store_news() -> int:
    """RSS 뉴스를 수집하고, 영향 분류를 수행하고, Supabase에 저장한 뒤 캐시를 갱신한다.

    Returns:
        수집/저장된 뉴스 건수.
    """
    global _news_cache

    try:
        raw = await fetch_rss_news()
        if not raw:
            logger.info("RSS에서 수집된 뉴스 없음, 캐시 유지")
            return 0

        unique = _deduplicate(raw)
        logger.info("RSS 수집 %d건, 중복 제거 후 %d건", len(raw), len(unique))

        # Impact classification for each article
        try:
            from services.impact_service import impact_service
            for article in unique:
                headline = article.get("headline", "")
                summary = article.get("summary", "")
                text = f"{headline} {summary}"
                impacts = impact_service.classify(text)
                article["impacts"] = [
                    {"etf_ticker": imp.etf_ticker, "level": imp.level}
                    for imp in impacts
                ]
            logger.info("영향 분류 완료: %d건", len(unique))
        except Exception as e:
            logger.warning("영향 분류 실패, impacts 없이 진행: %s", e)

        # Supabase 저장 시도
        stored = 0
        try:
            from services.supabase_client import get_supabase
            sb = get_supabase()

            for article in unique:
                try:
                    sb.table("news").upsert(
                        {
                            "headline": article["headline"],
                            "summary": article.get("summary", ""),
                            "source": article["source"],
                            "source_url": article["source_url"],
                            "published_at": article["published_at"],
                        },
                        on_conflict="source_url",
                    ).execute()
                    stored += 1
                except Exception as e:
                    logger.warning("Supabase 저장 실패 (개별): %s", e)

            logger.info("Supabase 저장 완료: %d건", stored)
        except Exception as e:
            logger.warning("Supabase 연결 실패, 캐시만 갱신: %s", e)

        # 번역 실행 (동기 — 스케줄러 job이므로 blocking OK)
        if unique and settings.ANTHROPIC_API_KEY:
            headlines = [a.get("headline_en", a.get("headline", "")) for a in unique]
            logger.info("번역 시작: %d건", len(headlines))
            for start in range(0, len(headlines), _BATCH_SIZE):
                batch = headlines[start:start + _BATCH_SIZE]
                numbered = "\n".join(f"[{i}] {h}" for i, h in enumerate(batch))
                prompt = _TRANSLATE_SUMMARISE_PROMPT.format(headlines=numbered)
                try:
                    client = _get_translate_client()
                    response = client.messages.create(
                        model=_TRANSLATE_MODEL,
                        max_tokens=8192,
                        messages=[{"role": "user", "content": prompt}],
                    )
                    text = response.content[0].text
                    if "```json" in text:
                        text = text.split("```json")[1].split("```")[0]
                    elif "```" in text:
                        text = text.split("```")[1].split("```")[0]
                    parsed = json.loads(text.strip())
                    for item in parsed:
                        idx = item.get("index", -1)
                        if 0 <= idx < len(batch) and item.get("ko"):
                            article = unique[start + idx]
                            article["headline"] = item["ko"]
                            if item.get("impact_reason"):
                                article["summary"] = item["impact_reason"]
                            article["summary_3line"] = item.get("summary_3line", "")
                            article["sentiment"] = item.get("sentiment", "중립")
                            article["translated"] = True
                    logger.info("번역 배치 완료: %d~%d / %d", start, start + len(batch), len(headlines))
                except Exception as e:
                    logger.error("번역 배치 실패 (%d~%d): %s", start, start + len(batch), e)

            translated_count = sum(1 for a in unique if a.get("translated"))
            logger.info("번역 완료: %d / %d건", translated_count, len(unique))

        # 캐시 갱신 (번역 완료 후)
        _news_cache = unique
        return len(unique)

    except Exception as e:
        logger.error("fetch_and_store_news 실패: %s", e)
        return 0


# ──────────────────────────────────────────────
# Service class (기존 API 호환)
# ──────────────────────────────────────────────

def _is_within_24h(published_at: str | None) -> bool:
    """Check if the published_at timestamp is within the last 24 hours."""
    if not published_at:
        return True  # 시간 정보 없으면 포함
    try:
        # Handle both 'Z' suffix and '+00:00'
        ts = published_at.replace("Z", "+00:00")
        pub = datetime.fromisoformat(ts)
        cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
        return pub >= cutoff
    except (ValueError, TypeError):
        return True  # 파싱 실패 시 포함


class NewsService:
    """Manages news data — RSS cache with mock fallback, filtering by ETF tickers."""

    async def get_all_news(self) -> list[FeedItem]:
        """Return news items from the last 24 hours, sorted by published_at (newest first).

        RSS 캐시가 있으면 캐시 기반 FeedItem을 반환하고 (keyword 기반 impact 포함),
        없으면 mock 데이터를 반환한다.
        """
        if _news_cache:
            from services.impact_service import impact_service

            items: list[FeedItem] = []
            for i, a in enumerate(_news_cache):
                pub_at = a.get("published_at")
                if not _is_within_24h(pub_at):
                    continue

                # 번역 안 된 기사는 건너뛰기 (번역 완료 후 자동 표시)
                if not a.get("translated", False):
                    continue

                # Build impacts from cached data or classify on the fly
                cached_impacts = a.get("impacts", [])
                if cached_impacts:
                    impacts = [
                        ETFImpact(etf_ticker=imp["etf_ticker"], level=imp["level"])
                        for imp in cached_impacts
                    ]
                else:
                    headline = a.get("headline", "")
                    summary = a.get("summary", "")
                    impacts = impact_service.classify(f"{headline} {summary}")

                # ETF 관련 뉴스만 표시 (impacts 없으면 제외)
                if not impacts:
                    continue

                items.append(
                    FeedItem(
                        id=f"rss-{i}",
                        headline=a["headline"],
                        impact_reason=a.get("summary", ""),
                        summary_3line=a.get("summary_3line", ""),
                        sentiment=a.get("sentiment", "중립"),
                        source=a.get("source"),
                        source_url=a.get("source_url"),
                        published_at=pub_at,
                        impacts=impacts,
                    )
                )
            return sorted(items, key=lambda n: n.published_at or "", reverse=True)

        # Fallback: mock data (always fresh due to dynamic timestamps)
        mock = _build_mock_news()
        return sorted(
            [m for m in mock if _is_within_24h(m.published_at)],
            key=lambda n: n.published_at or "",
            reverse=True,
        )

    async def get_news_for_etfs(self, tickers: list[str]) -> list[FeedItem]:
        """Filter news items that impact any of the given ETF tickers."""
        tickers_upper = {t.upper() for t in tickers}

        # Use all available news (RSS or mock)
        all_news = await self.get_all_news()

        results: list[FeedItem] = []
        for item in all_news:
            if any(imp.etf_ticker in tickers_upper for imp in item.impacts):
                results.append(item)

        # Sort by highest impact first
        def _sort_key(item: FeedItem) -> int:
            score = 0
            for imp in item.impacts:
                if imp.etf_ticker in tickers_upper:
                    if imp.level == "High":
                        score += 3
                    elif imp.level == "Medium":
                        score += 2
                    else:
                        score += 1
            return score

        results.sort(key=_sort_key, reverse=True)
        return results


async def translate_headlines(headlines: list[str]) -> list[str]:
    """Translate English news headlines to Korean using Claude API.

    Falls back to returning original headlines if the API key is missing
    or the API call fails.

    Args:
        headlines: List of English headline strings.

    Returns:
        List of Korean-translated headline strings (same order/length).
    """
    if not headlines:
        return []

    if not settings.ANTHROPIC_API_KEY:
        logger.warning("ANTHROPIC_API_KEY 미설정 — 원문 헤드라인 반환")
        return headlines

    # Build numbered headline list
    numbered = "\n".join(f"[{i}] {h}" for i, h in enumerate(headlines))
    prompt = TRANSLATE_PROMPT.format(headlines=numbered)

    try:
        client = _get_translate_client()
        response = client.messages.create(
            model=_TRANSLATE_MODEL,
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        )
        text = response.content[0].text
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]

        parsed: list[dict] = json.loads(text.strip())

        # Build index-to-translation map
        translation_map: dict[int, str] = {}
        for item in parsed:
            idx = item.get("index", -1)
            ko = item.get("ko", "")
            if 0 <= idx < len(headlines) and ko:
                translation_map[idx] = ko

        # Return translations in order, falling back to originals
        return [translation_map.get(i, h) for i, h in enumerate(headlines)]

    except Exception as e:
        logger.error("번역 API 호출 실패: %s", e)
        return headlines


news_service = NewsService()
