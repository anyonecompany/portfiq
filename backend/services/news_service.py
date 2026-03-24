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
import time as _time_mod
from datetime import datetime, timedelta, timezone

import feedparser
from google import genai
import httpx

from config import settings
from models.schemas import FeedItem, ETFImpact
from prompts.translate import TRANSLATE_PROMPT

logger = logging.getLogger(__name__)

_GEMINI_MODEL = settings.GEMINI_MODEL
_gemini_client: genai.Client | None = None

# Gemini rate limit tracking
_gemini_rate_limited_until: float = 0  # monotonic timestamp


def _is_gemini_rate_limited() -> bool:
    """Check if Gemini API is currently rate-limited."""
    return _time_mod.monotonic() < _gemini_rate_limited_until


def _set_gemini_rate_limited(backoff_seconds: float = 60) -> None:
    """Mark Gemini API as rate-limited for backoff_seconds."""
    global _gemini_rate_limited_until
    _gemini_rate_limited_until = _time_mod.monotonic() + backoff_seconds
    logger.warning("Gemini API rate limited, backing off for %.0fs", backoff_seconds)


def _get_gemini_client() -> genai.Client:
    """Return a lazily-initialised Gemini client for translation."""
    global _gemini_client
    if _gemini_client is None:
        _gemini_client = genai.Client(api_key=settings.GEMINI_API_KEY)
    return _gemini_client


# ──────────────────────────────────────────────
# Keyword-based sentiment fallback
# ──────────────────────────────────────────────

_POSITIVE_WORDS = [
    "상승",
    "호조",
    "성장",
    "급등",
    "반등",
    "최고",
    "호재",
    "수혜",
    "surge",
    "rally",
    "gain",
    "rise",
    "jump",
    "soar",
    "record",
    "beat",
    "exceed",
    "outperform",
    "bullish",
    "upgrade",
]
_NEGATIVE_WORDS = [
    "하락",
    "급락",
    "폭락",
    "악재",
    "위기",
    "손실",
    "둔화",
    "우려",
    "리스크",
    "제재",
    "규제",
    "관세",
    "파산",
    "디폴트",
    "drop",
    "fall",
    "plunge",
    "crash",
    "decline",
    "loss",
    "risk",
    "tariff",
    "sanction",
    "downgrade",
    "bearish",
    "recession",
    "layoff",
]


def _keyword_sentiment(text: str) -> str:
    """Keyword-based sentiment fallback when Gemini is unavailable.

    Returns:
        "호재", "위험", or "중립".
    """
    t = text.lower()
    pos = sum(1 for w in _POSITIVE_WORDS if w in t)
    neg = sum(1 for w in _NEGATIVE_WORDS if w in t)
    if pos > neg:
        return "호재"
    if neg > pos:
        return "위험"
    return "중립"


_SENTIMENT_NORMALIZE: dict[str, str] = {
    "호재": "호재",
    "위험": "위험",
    "중립": "중립",
    "positive": "호재",
    "negative": "위험",
    "neutral": "중립",
    "bullish": "호재",
    "bearish": "위험",
    "긍정": "호재",
    "부정": "위험",
}


def _normalize_sentiment(raw: str) -> str:
    """Normalize sentiment value from Gemini or other sources to Korean.

    Handles English/Korean variants and returns "호재", "위험", or "중립".

    Args:
        raw: Raw sentiment string from any source.

    Returns:
        Normalized Korean sentiment: "호재", "위험", or "중립".
    """
    return _SENTIMENT_NORMALIZE.get(raw.strip().lower(), "중립")


# ──────────────────────────────────────────────
# RSS feeds — US financial news (primary)
# ──────────────────────────────────────────────

RSS_FEEDS_EN: list[tuple[str, str]] = [
    ("https://finance.yahoo.com/news/rssindex", "Yahoo Finance"),
    ("https://feeds.marketwatch.com/marketwatch/topstories", "MarketWatch"),
    (
        "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=10001147",
        "CNBC",
    ),
    ("https://www.investing.com/rss/news.rss", "Investing.com"),
    (
        "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=20910258",
        "CNBC ETF",
    ),
    ("https://feeds.marketwatch.com/marketwatch/marketpulse", "MarketWatch Pulse"),
    ("https://feeds.bloomberg.com/markets/news.rss", "Bloomberg Markets"),
    (
        "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=10000664",
        "CNBC Tech",
    ),
    (
        "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=19836768",
        "CNBC Earnings",
    ),
    ("https://feeds.reuters.com/reuters/businessNews", "Reuters Business"),
]

RSS_FEEDS_KR: list[tuple[str, str]] = []
RSS_FEEDS = [url for url, _ in RSS_FEEDS_EN]

# ──────────────────────────────────────────────
# Real-time news cache
# ──────────────────────────────────────────────

_news_cache: list[dict] = []
_rss_ever_succeeded = False  # True once at least one RSS collection succeeds
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
            is_mock=True,
            headline="FOMC 금리 동결 결정, 시장 안도 랠리 예상",
            impact_reason=(
                "연준이 기준금리를 5.25~5.50%에서 동결했습니다.\n"
                "파월 의장은 연내 인하 가능성을 시사하며 시장에 긍정적 신호를 보냈습니다.\n"
                "기술주 중심의 QQQ와 대형주 중심의 VOO에 상승 모멘텀이 예상됩니다."
            ),
            source="Reuters",
            source_url="https://reuters.com/markets/fomc-2026",
            sentiment="호재",
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
            is_mock=True,
            headline="NVIDIA 분기 실적 발표, 매출 260% 급증",
            impact_reason=(
                "NVIDIA가 AI 칩 수요 폭증에 힘입어 분기 매출 $26B을 기록했습니다.\n"
                "데이터센터 부문이 전체 매출의 78%를 차지하며 기대치를 상회했습니다.\n"
                "반도체 ETF(SOXL, SOXX)와 기술주 ETF(QQQ)에 즉각적 상승 압력이 예상됩니다."
            ),
            sentiment="호재",
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
            is_mock=True,
            headline="SCHD 분기 배당 $0.72 발표, 전년 대비 8% 증가",
            impact_reason=(
                "SCHD가 분기당 $0.72 배당을 확정하며 배당 성장세를 이어갔습니다.\n"
                "연간 배당수익률은 약 3.8%로, 인컴 투자자들에게 매력적입니다.\n"
                "배당주 중심 포트폴리오 재편 수요가 증가할 수 있습니다."
            ),
            sentiment="호재",
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
            is_mock=True,
            headline="ARK Invest, Tesla 목표가 $350 유지하며 추가 매수",
            impact_reason=(
                "캐시 우드가 이끄는 ARK Invest가 Tesla 주식을 5일 연속 매수했습니다.\n"
                "자율주행 FSD V13 출시 기대감이 핵심 근거로 제시되었습니다.\n"
                "ARKK ETF 내 Tesla 비중이 12%로 확대되며 변동성이 커질 수 있습니다."
            ),
            sentiment="중립",
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
            is_mock=True,
            headline="국제유가 WTI $85 돌파, OPEC+ 감산 연장 영향",
            impact_reason=(
                "OPEC+가 2분기까지 일일 200만 배럴 감산을 연장하기로 합의했습니다.\n"
                "WTI 유가가 $85를 넘기며 에너지 섹터 전반에 호재로 작용합니다.\n"
                "에너지 ETF(XLE)의 상승과 함께 소비재 비용 부담으로 인한 VOO 하방 리스크도 존재합니다."
            ),
            sentiment="위험",
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
            is_mock=True,
            headline="미 국채 10년물 금리 4.1%로 하락, 채권 랠리 시작",
            impact_reason=(
                "경기 둔화 우려로 미 국채 10년물 금리가 4.1%까지 떨어졌습니다.\n"
                "금리 하락은 장기 채권 가격 상승으로 이어져 TLT에 강한 호재입니다.\n"
                "동시에 금리 민감 성장주(QQQ, ARKK)에도 긍정적 영향을 줍니다."
            ),
            sentiment="호재",
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
            is_mock=True,
            headline="골드만삭스, 2026년 S&P 500 목표치 6,200 제시",
            impact_reason=(
                "골드만삭스가 S&P 500 연말 목표치를 기존 5,800에서 6,200으로 상향했습니다.\n"
                "AI 생산성 향상과 기업 실적 개선이 핵심 근거입니다.\n"
                "S&P 500 추종 ETF(SPY, VOO, IVV) 모두에 긍정적 시그널입니다."
            ),
            sentiment="호재",
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
            is_mock=True,
            headline="중국 AI 스타트업 DeepSeek, 미국 반도체 수입 규제 우회 논란",
            impact_reason=(
                "DeepSeek가 미국 반도체 수출 규제를 우회해 고성능 칩을 확보했다는 보도가 나왔습니다.\n"
                "미-중 기술 갈등 심화는 중국 인터넷 ETF(KWEB)에 하방 리스크를 높입니다.\n"
                "반면 미국 반도체 기업 보호 정책 강화로 SOXL에는 복합적 영향이 예상됩니다."
            ),
            sentiment="위험",
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
            is_mock=True,
            headline="금값 사상 최고 $2,400 돌파, 안전자산 선호 강화",
            impact_reason=(
                "지정학적 리스크와 달러 약세로 금 가격이 사상 최고치를 경신했습니다.\n"
                "중앙은행 금 매수세가 지속되며 GLD ETF로의 자금 유입이 가속화되고 있습니다.\n"
                "안전자산 선호가 강해지면 성장주 ETF에서 자금 이탈이 나타날 수 있습니다."
            ),
            sentiment="중립",
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
            is_mock=True,
            headline="JP모건, JEPI 운용자산 $40B 돌파 발표",
            impact_reason=(
                "JEPI가 출시 4년 만에 운용자산 $40B을 돌파하며 인컴 ETF 시장 1위를 굳혔습니다.\n"
                "커버드콜 전략의 안정적 수익 제공이 인기 요인으로 분석됩니다.\n"
                "배당 투자 트렌드 지속으로 SCHD와 함께 자금 유입이 이어질 전망입니다."
            ),
            sentiment="호재",
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

_TRANSLATE_SUMMARISE_PROMPT = """아래 영문 뉴스 헤드라인들을 한국어로 번역하고, 각 헤드라인에 대해 ETF 투자자 관점의 3줄 요약과 투자 심리 평가를 생성하세요.

{headlines}

JSON 배열로 응답하세요:
[
  {{"index": 0, "ko": "한국어 번역 헤드라인", "impact_reason": "줄1\\n줄2\\n줄3", "summary_3line": "• 무슨 일이 일어났는지 한 줄\\n• 이게 왜 ETF에 호재/위험인지 한 줄\\n• ETF 투자자가 지금 어떻게 해야 하는지 한 줄", "sentiment": "호재"}},
  ...
]

규칙:
- 금융/투자 용어는 한국 투자자에게 익숙한 표현 사용
- 헤드라인은 간결하게 번역 (원문보다 짧게)
- 헤드라인에 이모지 사용 금지 (순수 한국어 텍스트만)
- impact_reason은 반드시 3줄: (1) 사실 요약 (2) 시장 영향 분석 (3) 관련 ETF 영향
- summary_3line은 반드시 3줄 (• 로 시작, \\n으로 구분):
  (1) 무슨 일이 일어났는지 — 핵심 사건을 한 문장으로
  (2) 이게 왜 호재/위험인지 — 관련 ETF(QQQ, SPY, XLE 등)를 구체적으로 언급하며 영향 설명
  (3) 투자자 액션 — "보유 유지", "비중 확대 검토", "리스크 주시" 등 구체적 행동 제안
- sentiment는 반드시 "호재", "중립", "위험" 중 하나:
  - 호재: 관련 ETF 주가 상승/긍정적 영향이 예상되는 뉴스
  - 중립: 방향성이 불명확하거나 영향이 제한적인 뉴스
  - 위험: 관련 ETF 주가 하락/부정적 영향이 예상되는 뉴스
- \\n으로 줄 구분
"""


_BATCH_SIZE = (
    10  # 한 번에 번역할 헤드라인 수 (summary_3line+sentiment 추가로 출력 증가)
)


async def _translate_batch(headlines: list[str]) -> list[dict[str, str]]:
    """Translate a single batch of headlines (max ~15).

    Returns list of dicts with 'ko' and 'impact_reason' keys.
    Handles Gemini 429 rate limits with backoff.
    Retries up to 3 times with exponential backoff on timeout/transient errors.
    """
    fallback = [
        {
            "ko": h,
            "impact_reason": "",
            "summary_3line": f"• {h}",
            "sentiment": _keyword_sentiment(h),
        }
        for h in headlines
    ]

    # Rate limit 상태면 즉시 fallback 반환 (대기하지 않음)
    if _is_gemini_rate_limited():
        logger.info(
            "Gemini rate limited, 키워드 기반 sentiment 반환 (배치 %d건)",
            len(headlines),
        )
        return fallback

    numbered = "\n".join(f"[{i}] {h}" for i, h in enumerate(headlines))
    prompt = _TRANSLATE_SUMMARISE_PROMPT.format(headlines=numbered)

    import asyncio

    for attempt in range(3):  # 최대 3회 시도
        try:
            client = _get_gemini_client()

            def _gemini_sync() -> str:
                response = client.models.generate_content(
                    model=_GEMINI_MODEL, contents=prompt
                )
                return response.text if response.text else ""

            try:
                text = await asyncio.wait_for(
                    asyncio.to_thread(_gemini_sync),
                    timeout=30,
                )
            except asyncio.TimeoutError:
                logger.warning(
                    "Gemini 번역 배치 타임아웃 (30s, attempt %d/3)", attempt + 1
                )
                if attempt < 2:
                    await asyncio.sleep(2**attempt)
                    continue
                return fallback

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
                        "sentiment": _normalize_sentiment(
                            item.get("sentiment", "중립")
                        ),
                    }

            return [
                result_map.get(
                    i,
                    {
                        "ko": h,
                        "impact_reason": "",
                        "summary_3line": f"• {h}",
                        "sentiment": "중립",
                    },
                )
                for i, h in enumerate(headlines)
            ]

        except Exception as e:
            # Gemini 429 rate limit 감지
            err_str = str(e).lower()
            if "429" in err_str or "resource_exhausted" in err_str or "rate" in err_str:
                _set_gemini_rate_limited(60)  # 60초 backoff
                return fallback
            logger.error("번역 배치 실패 (attempt %d/3): %s", attempt + 1, e)
            if attempt < 2:
                await asyncio.sleep(2**attempt)
                continue
            return fallback

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

    if not settings.GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY 미설정 — 원문 헤드라인 반환")
        return [{"ko": h, "impact_reason": ""} for h in headlines]

    results: list[dict[str, str]] = []
    for start in range(0, len(headlines), _BATCH_SIZE):
        batch = headlines[start : start + _BATCH_SIZE]
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

    각 피드별로 최대 2회 재시도(3초 간격). 일부 피드만 성공해도 결과를 반환한다.
    """
    global _rss_ever_succeeded
    articles: list[dict] = []

    feed_success_count = 0
    feed_fail_count = 0

    async with httpx.AsyncClient(timeout=15.0) as client:
        for feed_url, source_name in RSS_FEEDS_EN:
            success = False
            for attempt in range(3):  # 최초 1회 + 재시도 2회
                try:
                    resp = await client.get(
                        feed_url,
                        headers={"User-Agent": "Mozilla/5.0 (compatible; Portfiq/1.0)"},
                    )
                    resp.raise_for_status()
                    feed = await asyncio.to_thread(feedparser.parse, resp.text)

                    for entry in feed.entries[:10]:
                        published = entry.get("published_parsed")
                        pub_dt = (
                            datetime(
                                published[0],
                                published[1],
                                published[2],
                                published[3],
                                published[4],
                                published[5],
                                tzinfo=timezone.utc,
                            )
                            if published
                            else datetime.now(timezone.utc)
                        )

                        articles.append(
                            {
                                "headline_en": entry.get("title", ""),
                                "headline": entry.get("title", ""),
                                "summary": entry.get("summary", ""),
                                "source": source_name,
                                "source_url": entry.get("link", ""),
                                "published_at": pub_dt.isoformat(),
                                "translated": False,
                            }
                        )
                    success = True
                    feed_success_count += 1
                    break
                except httpx.TimeoutException as e:
                    logger.error(
                        "RSS 타임아웃 (%s, attempt %d/3): %s",
                        source_name,
                        attempt + 1,
                        e,
                    )
                    if attempt < 2:
                        await asyncio.sleep(3)
                except httpx.HTTPStatusError as e:
                    logger.error(
                        "RSS HTTP 에러 (%s, attempt %d/3): status=%d, %s",
                        source_name,
                        attempt + 1,
                        e.response.status_code,
                        e,
                    )
                    if attempt < 2:
                        await asyncio.sleep(3)
                except Exception as e:
                    logger.error(
                        "RSS 수집 실패 (%s, attempt %d/3): %s: %s",
                        source_name,
                        attempt + 1,
                        type(e).__name__,
                        e,
                    )
                    if attempt < 2:
                        await asyncio.sleep(3)

            if success:
                _rss_ever_succeeded = True
            else:
                feed_fail_count += 1
                logger.warning("RSS 피드 최종 실패: %s (%s)", source_name, feed_url)

    logger.info(
        "RSS 수집 결과: 성공=%d/%d, 실패=%d, 기사=%d건",
        feed_success_count,
        len(RSS_FEEDS_EN),
        feed_fail_count,
        len(articles),
    )
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

        if not settings.GEMINI_API_KEY:
            logger.warning("GEMINI_API_KEY 미설정 — 번역 건너뜀")
            return

        if _is_gemini_rate_limited():
            logger.info("Gemini rate limited, 백그라운드 번역 스킵")
            return

        headlines = [a["headline_en"] for a in untranslated]
        logger.info("백그라운드 번역 시작: %d건", len(headlines))

        # Synchronous batch translation
        for start in range(0, len(headlines), _BATCH_SIZE):
            # 배치 간 rate limit 재확인
            if _is_gemini_rate_limited():
                logger.info("Gemini rate limited, 남은 배치 스킵")
                break

            batch = headlines[start : start + _BATCH_SIZE]
            numbered = "\n".join(f"[{i}] {h}" for i, h in enumerate(batch))
            prompt = _TRANSLATE_SUMMARISE_PROMPT.format(headlines=numbered)

            try:
                client = _get_gemini_client()
                response = client.models.generate_content(
                    model=_GEMINI_MODEL, contents=prompt
                )
                text = response.text if response.text else ""
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
                for i, article in enumerate(untranslated[start : start + len(batch)]):
                    tr = result_map.get(i)
                    if tr:
                        article["headline"] = tr["ko"]
                        if tr.get("impact_reason"):
                            article["summary"] = tr["impact_reason"]
                        article["summary_3line"] = tr.get("summary_3line", "")
                        raw_sentiment = tr.get("sentiment") or _keyword_sentiment(
                            article.get("original_headline", article["headline"])
                        )
                        article["sentiment"] = _normalize_sentiment(raw_sentiment)
                        article["translated"] = True

                logger.info(
                    "번역 배치 완료: %d~%d / %d",
                    start,
                    start + len(batch),
                    len(headlines),
                )
                _time_mod.sleep(1.5)  # rate limit 방지 — 배치 간 1.5초 대기

            except Exception as e:
                err_str = str(e).lower()
                if (
                    "429" in err_str
                    or "resource_exhausted" in err_str
                    or "rate" in err_str
                ):
                    _set_gemini_rate_limited(60)
                    break  # rate limited — 남은 배치 스킵
                logger.error("번역 배치 실패 (%d~%d): %s", start, start + len(batch), e)

        translated_count = sum(1 for a in _news_cache if a.get("translated"))
        logger.info(
            "백그라운드 번역 완료: %d / %d건", translated_count, len(_news_cache)
        )

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
    global _news_cache, _rss_ever_succeeded

    try:
        raw = await fetch_rss_news()
        if not raw:
            logger.warning("모든 RSS 피드 실패 — mock 뉴스로 캐시 갱신")
            mock_items = _build_mock_news()
            _news_cache = [
                {
                    "headline": m.headline,
                    "headline_en": m.headline,
                    "summary": m.impact_reason,
                    "source": m.source or "",
                    "source_url": m.source_url or "",
                    "published_at": m.published_at or "",
                    "translated": True,
                    "is_mock": True,
                    "impacts": [
                        {"etf_ticker": imp.etf_ticker, "level": imp.level}
                        for imp in m.impacts
                    ],
                }
                for m in mock_items
            ]
            return len(_news_cache)

        _rss_ever_succeeded = True

        unique = _deduplicate(raw)
        logger.info("RSS 수집 %d건, 중복 제거 후 %d건", len(raw), len(unique))

        # Impact classification + 키워드 기반 sentiment/summary fallback (동기 → thread로 실행)
        def _classify_impacts() -> None:
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
                    # 번역 전 키워드 기반 sentiment/summary_3line fallback
                    if not article.get("sentiment"):
                        article["sentiment"] = _keyword_sentiment(headline)
                    if not article.get("summary_3line"):
                        article["summary_3line"] = f"• {headline}"
                logger.info("영향 분류 완료: %d건", len(unique))
            except Exception as e:
                logger.warning("영향 분류 실패, impacts 없이 진행: %s", e)

        await asyncio.to_thread(_classify_impacts)

        # Supabase 저장 (동기 → thread로 실행)
        def _store_to_supabase() -> int:
            count = 0
            try:
                from services.supabase_client import (
                    get_supabase_service as get_supabase,
                )

                sb = get_supabase()

                for article in unique:
                    try:
                        row: dict[str, object] = {
                            "headline": article["headline"],
                            "impact_reason": article.get("summary", ""),
                            "source": article["source"],
                            "source_url": article["source_url"],
                            "published_at": article["published_at"],
                            "raw_data": {
                                "headline_en": article.get("headline_en", ""),
                                "impacts": article.get("impacts", []),
                                "sentiment": article.get("sentiment", "중립"),
                                "summary_3line": article.get("summary_3line", ""),
                            },
                        }
                        try:
                            sb.table("news").upsert(
                                row,
                                on_conflict="source_url",
                            ).execute()
                        except Exception:
                            existing = (
                                sb.table("news")
                                .select("id")
                                .eq("source_url", article["source_url"])
                                .limit(1)
                                .execute()
                            )
                            if not existing.data:
                                sb.table("news").insert(row).execute()
                            else:
                                sb.table("news").update(row).eq(
                                    "source_url", article["source_url"]
                                ).execute()
                        count += 1
                    except Exception as e:
                        logger.warning("Supabase 저장 실패 (개별): %s", e)

                logger.info("Supabase 저장 완료: %d건", count)
            except Exception as e:
                logger.warning("Supabase 연결 실패, 캐시만 갱신: %s", e)
            return count

        await asyncio.to_thread(_store_to_supabase)

        # 번역 실행 (동기 Gemini + Supabase → thread로 실행)
        def _translate_and_update() -> None:
            if not (
                unique and settings.GEMINI_API_KEY and not _is_gemini_rate_limited()
            ):
                return

            headlines = [a.get("headline_en", a.get("headline", "")) for a in unique]
            logger.info("번역 시작: %d건 (Gemini %s)", len(headlines), _GEMINI_MODEL)
            for start in range(0, len(headlines), _BATCH_SIZE):
                if _is_gemini_rate_limited():
                    logger.info("Gemini rate limited, 남은 번역 배치 스킵")
                    break

                batch = headlines[start : start + _BATCH_SIZE]
                numbered = "\n".join(f"[{i}] {h}" for i, h in enumerate(batch))
                prompt = _TRANSLATE_SUMMARISE_PROMPT.format(headlines=numbered)
                try:
                    client = _get_gemini_client()
                    response = client.models.generate_content(
                        model=_GEMINI_MODEL, contents=prompt
                    )
                    text = response.text if response.text else ""
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
                            raw_sentiment = item.get("sentiment") or _keyword_sentiment(
                                article.get("original_headline", article["headline"])
                            )
                            article["sentiment"] = _normalize_sentiment(raw_sentiment)
                            article["translated"] = True
                    logger.info(
                        "번역 배치 완료: %d~%d / %d",
                        start,
                        start + len(batch),
                        len(headlines),
                    )
                    _time_mod.sleep(1.5)  # rate limit 방지 — 배치 간 1.5초 대기
                except Exception as e:
                    err_str = str(e).lower()
                    if (
                        "429" in err_str
                        or "resource_exhausted" in err_str
                        or "rate" in err_str
                    ):
                        _set_gemini_rate_limited(60)
                        break
                    logger.error(
                        "번역 배치 실패 (%d~%d): %s", start, start + len(batch), e
                    )

            translated_count = sum(1 for a in unique if a.get("translated"))
            logger.info("번역 완료: %d / %d건", translated_count, len(unique))

            # 번역된 헤드라인을 Supabase에 업데이트
            try:
                from services.supabase_client import (
                    get_supabase_service as get_supabase,
                )

                sb_update = get_supabase()
                update_count = 0
                for article in unique:
                    if article.get("translated") and article.get("source_url"):
                        try:
                            update_row: dict[str, str] = {
                                "headline": article["headline"],
                                "impact_reason": article.get("summary", ""),
                            }
                            sb_update.table("news").update(update_row).eq(
                                "source_url", article["source_url"]
                            ).execute()
                            update_count += 1
                        except Exception:
                            pass
                logger.info("Supabase 번역 업데이트: %d건", update_count)
            except Exception as e:
                logger.warning("Supabase 번역 업데이트 실패: %s", e)

        # 먼저 영문 원문으로 캐시 갱신 (빈 캐시 방지)
        _news_cache = unique

        await asyncio.to_thread(_translate_and_update)

        # 번역 완료 후 캐시 갱신 (unique는 in-place 번역됨)
        _news_cache = unique

        # 피드 캐시 무효화 — 번역된 데이터로 재생성되도록
        try:
            from services.cache import clear_cache as _clear

            _clear()
            logger.info("피드 캐시 무효화 완료 (번역 반영)")
        except Exception:
            pass
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

        데이터 소스 우선순위:
        1. 인메모리 캐시 (TTL 15분)
        2. _news_cache (RSS 수집 결과, 번역 여부 무관)
        3. Supabase news 테이블 (서버 재시작 후 복구용)
        4. Mock 데이터 (최후 fallback)
        """
        from services.cache import get_cached, set_cached

        cache_key = "feed_latest"
        cached = get_cached(cache_key)
        if cached is not None:
            return cached

        if _news_cache:
            result = self._build_feed_items_from_cache(_news_cache)
            if result:
                set_cached(cache_key, result)
                return result

        # Supabase fallback: 서버 재시작 후 _news_cache가 비어있을 때
        sb_articles = await self._load_from_supabase()
        if sb_articles:
            result = self._build_feed_items_from_cache(sb_articles)
            if result:
                set_cached(cache_key, result)
                return result

        # 최후 fallback: RSS 수집 성공한 적이 없을 때만 mock 사용
        if not _rss_ever_succeeded:
            mock = _build_mock_news()
            result = sorted(
                [m for m in mock if _is_within_24h(m.published_at)],
                key=lambda n: n.published_at or "",
                reverse=True,
            )
            set_cached(cache_key, result)
            return result

        return []

    def _build_feed_items_from_cache(self, articles: list[dict]) -> list[FeedItem]:
        """캐시된 뉴스 기사 목록을 FeedItem 리스트로 변환한다.

        번역되지 않은 기사도 영문 원문으로 포함한다.

        Args:
            articles: RSS 수집 또는 Supabase에서 로드한 기사 딕셔너리 리스트.

        Returns:
            최신순으로 정렬된 FeedItem 리스트.
        """
        from services.impact_service import impact_service

        items: list[FeedItem] = []
        for i, a in enumerate(articles):
            pub_at = a.get("published_at")
            if not _is_within_24h(pub_at):
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

    async def _load_from_supabase(self) -> list[dict]:
        """Supabase news 테이블에서 최근 24시간 뉴스를 로드한다.

        서버 재시작 후 인메모리 캐시가 비어있을 때 사용한다.

        Returns:
            뉴스 기사 딕셔너리 리스트. 실패 시 빈 리스트.
        """
        try:
            from services.supabase_client import get_supabase_service as get_supabase

            sb = get_supabase()

            cutoff = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
            resp = (
                sb.table("news")
                .select(
                    "id,headline,impact_reason,source,source_url,published_at,raw_data"
                )
                .gte("published_at", cutoff)
                .order("published_at", desc=True)
                .limit(100)
                .execute()
            )

            if not resp.data:
                logger.info("Supabase news 테이블에 최근 24시간 데이터 없음")
                return []

            articles: list[dict] = []
            for row in resp.data:
                # impacts는 raw_data JSONB 안에 저장됨
                raw_data = row.get("raw_data") or {}
                impacts = (
                    raw_data.get("impacts", []) if isinstance(raw_data, dict) else []
                )

                headline = row.get("headline", "")
                sentiment = (
                    raw_data.get("sentiment", "중립")
                    if isinstance(raw_data, dict)
                    else "중립"
                )
                summary_3line = (
                    raw_data.get("summary_3line", "")
                    if isinstance(raw_data, dict)
                    else ""
                )
                # fallback: summary_3line이 비어있으면 headline 기반 1줄 요약
                if not summary_3line and headline:
                    summary_3line = f"• {headline}"

                articles.append(
                    {
                        "headline": headline,
                        "summary": row.get("impact_reason", ""),
                        "source": row.get("source", ""),
                        "source_url": row.get("source_url", ""),
                        "published_at": row.get("published_at", ""),
                        "impacts": impacts,
                        "sentiment": sentiment,
                        "summary_3line": summary_3line,
                        "translated": True,
                    }
                )

            logger.info("Supabase에서 뉴스 %d건 로드 (서버 재시작 복구)", len(articles))
            return articles

        except Exception as e:
            logger.warning("Supabase 뉴스 로드 실패: %s", e)
            return []

    async def get_all_news_paginated(
        self, *, offset: int = 0, limit: int = 20
    ) -> tuple[list[FeedItem], int]:
        """Return paginated news items, including items older than 24 hours.

        Unlike get_all_news() which only returns the last 24 hours, this method
        supports browsing older news via offset/limit for infinite scroll.

        Args:
            offset: Number of items to skip.
            limit: Maximum number of items to return.

        Returns:
            Tuple of (paginated FeedItem list, total count).
        """
        from services.cache import get_cached, set_cached

        # First, gather the full sorted list (from cache or build it)
        cache_key = "feed_all_sorted"
        all_items: list[FeedItem] | None = get_cached(cache_key)

        if all_items is None:
            all_items = await self._get_all_items_no_time_filter()
            if all_items:
                set_cached(cache_key, all_items)

        total = len(all_items)
        page = all_items[offset : offset + limit]
        return page, total

    async def _get_all_items_no_time_filter(self) -> list[FeedItem]:
        """Gather all available news items without the 24-hour filter.

        Data source priority:
        1. _news_cache (RSS collection results)
        2. Supabase news table (server restart recovery)
        3. Mock data (final fallback)

        Returns:
            All FeedItem instances sorted newest-first.
        """
        if _news_cache:
            items = self._build_feed_items_unfiltered(_news_cache)
            if items:
                return items

        sb_articles = await self._load_from_supabase_all()
        if sb_articles:
            items = self._build_feed_items_unfiltered(sb_articles)
            if items:
                return items

        # RSS 수집 성공한 적이 없을 때만 mock 사용
        if not _rss_ever_succeeded:
            mock = _build_mock_news()
            return sorted(mock, key=lambda n: n.published_at or "", reverse=True)

        return []

    def _build_feed_items_unfiltered(self, articles: list[dict]) -> list[FeedItem]:
        """Build FeedItem list from articles WITHOUT the 24-hour filter.

        Args:
            articles: Raw article dicts.

        Returns:
            Sorted FeedItem list (newest first).
        """
        from services.impact_service import impact_service

        items: list[FeedItem] = []
        for i, a in enumerate(articles):
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
                    published_at=a.get("published_at"),
                    impacts=impacts,
                )
            )
        return sorted(items, key=lambda n: n.published_at or "", reverse=True)

    async def _load_from_supabase_all(self) -> list[dict]:
        """Load all news from Supabase without time filter (for pagination).

        Returns:
            News article dicts sorted newest-first. Empty list on failure.
        """
        try:
            from services.supabase_client import get_supabase_service as get_supabase

            sb = get_supabase()

            resp = (
                sb.table("news")
                .select(
                    "id,headline,impact_reason,source,source_url,published_at,raw_data"
                )
                .order("published_at", desc=True)
                .limit(500)
                .execute()
            )

            if not resp.data:
                return []

            articles: list[dict] = []
            for row in resp.data:
                raw_data = row.get("raw_data") or {}
                impacts = (
                    raw_data.get("impacts", []) if isinstance(raw_data, dict) else []
                )
                articles.append(
                    {
                        "headline": row.get("headline", ""),
                        "summary": row.get("impact_reason", ""),
                        "source": row.get("source", ""),
                        "source_url": row.get("source_url", ""),
                        "published_at": row.get("published_at", ""),
                        "impacts": impacts,
                        "translated": True,
                    }
                )
            return articles

        except Exception as e:
            logger.warning("Supabase 전체 뉴스 로드 실패: %s", e)
            return []

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
    """Translate English news headlines to Korean using Gemini API.

    Falls back to returning original headlines if the API key is missing,
    rate limited, or the API call fails.

    Args:
        headlines: List of English headline strings.

    Returns:
        List of Korean-translated headline strings (same order/length).
    """
    if not headlines:
        return []

    if not settings.GEMINI_API_KEY:
        logger.warning("GEMINI_API_KEY 미설정 — 원문 헤드라인 반환")
        return headlines

    if _is_gemini_rate_limited():
        logger.info("Gemini rate limited, 원문 헤드라인 반환")
        return headlines

    # Build numbered headline list
    numbered = "\n".join(f"[{i}] {h}" for i, h in enumerate(headlines))
    prompt = TRANSLATE_PROMPT.format(headlines=numbered)

    try:
        import asyncio

        client = _get_gemini_client()

        def _gemini_translate_sync() -> str:
            response = client.models.generate_content(
                model=_GEMINI_MODEL, contents=prompt
            )
            return response.text if response.text else ""

        try:
            text = await asyncio.wait_for(
                asyncio.to_thread(_gemini_translate_sync),
                timeout=15,
            )
        except asyncio.TimeoutError:
            logger.warning("Gemini 번역 타임아웃 (15s)")
            return headlines

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
        err_str = str(e).lower()
        if "429" in err_str or "resource_exhausted" in err_str or "rate" in err_str:
            _set_gemini_rate_limited(60)
        logger.error("번역 API 호출 실패: %s", e)
        return headlines


news_service = NewsService()
