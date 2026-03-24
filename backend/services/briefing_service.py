"""AI 브리핑 생성 서비스 — Gemini API 연동.

Gemini API 호출은 동기 I/O이므로 asyncio.to_thread()로 스레드 풀에서 실행하여
이벤트 루프 블로킹을 방지한다. 12초 타임아웃을 적용한다.

핵심 설계 원칙:
- API 응답은 항상 2초 이내 (캐시/mock에서 즉시 반환)
- Gemini API 호출은 백그라운드에서만 수행 (요청 시점이 아님)
- 스케줄러가 미리 생성한 브리핑을 캐시에서 반환
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from google import genai

from config import settings
from models.schemas import BriefingResponse, ETFChange
from prompts.briefing import MORNING_PROMPT, NIGHT_PROMPT

logger = logging.getLogger(__name__)

_GEMINI_MODEL = settings.GEMINI_MODEL
_GEMINI_TIMEOUT = 30  # Gemini API 호출 타임아웃 (초) — 프롬프트 복잡도 증가로 12→30s

_gemini_client: genai.Client | None = None

# 마지막으로 성공한 브리핑 저장 (캐시 만료 후에도 반환 가능)
_last_morning_briefings: dict[str, BriefingResponse] = {}
_last_night_briefings: dict[str, BriefingResponse] = {}


def _get_gemini_client() -> genai.Client:
    """Return a lazily-initialised Gemini client."""
    global _gemini_client
    if _gemini_client is None:
        _gemini_client = genai.Client(api_key=settings.GEMINI_API_KEY)
    return _gemini_client


def _call_gemini_sync(prompt: str) -> dict | None:
    """Gemini API 동기 호출 + JSON 파싱 (스레드 풀에서 실행).

    Args:
        prompt: The formatted prompt to send to Gemini.

    Returns:
        Parsed JSON dict on success, None on failure.
    """
    try:
        client = _get_gemini_client()
        response = client.models.generate_content(
            model=_GEMINI_MODEL,
            contents=prompt,
        )
        text = response.text or ""
        # Extract JSON from response
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        return json.loads(text.strip())
    except Exception as e:
        logger.error("Gemini API 호출 실패: %s", e)
        return None


async def _call_gemini(prompt: str) -> dict | None:
    """Gemini API 비동기 호출 — 스레드 풀 + 타임아웃.

    Args:
        prompt: The formatted prompt to send to Gemini.

    Returns:
        Parsed JSON dict on success, None on failure/timeout.
    """
    try:
        return await asyncio.wait_for(
            asyncio.to_thread(_call_gemini_sync, prompt),
            timeout=_GEMINI_TIMEOUT,
        )
    except asyncio.TimeoutError:
        logger.warning("Gemini API 타임아웃 (%ds)", _GEMINI_TIMEOUT)
        return None
    except Exception as e:
        logger.error("Gemini API 호출 실패: %s", e)
        return None


def _build_briefing_from_ai(data: dict, briefing_type: str) -> BriefingResponse:
    """Convert AI JSON output into a BriefingResponse.

    Args:
        data: Parsed JSON dict from AI.
        briefing_type: "morning" or "night".

    Returns:
        A validated BriefingResponse.
    """
    etf_changes = [
        ETFChange(
            ticker=c.get("ticker", ""),
            change_pct=c.get("change_pct", 0.0),
            direction=c.get("direction", "flat"),
            cause=c.get("cause", ""),
        )
        for c in data.get("etf_changes", [])
    ]

    # Morning uses key_events, night uses checkpoints
    checkpoints: list[str] = []
    if briefing_type == "morning":
        checkpoints = data.get("key_events", [])
    else:
        raw_checkpoints = data.get("checkpoints", [])
        for cp in raw_checkpoints:
            if isinstance(cp, dict):
                event = cp.get("event", "")
                time_ = cp.get("time", "")
                impact = cp.get("impact", "")
                checkpoints.append(
                    f"{time_} — {event}: {impact}" if time_ else f"{event}: {impact}"
                )
            else:
                checkpoints.append(str(cp))

    return BriefingResponse(
        type=briefing_type,
        title=data.get(
            "title", f"{'모닝' if briefing_type == 'morning' else '나이트'} 브리핑"
        ),
        summary=data.get("summary", ""),
        etf_changes=etf_changes,
        checkpoints=checkpoints,
        generated_at=datetime.now(timezone.utc).isoformat(),
    )


# ──────────────────────────────────────────────
# Mock briefing data (fallback)
# ──────────────────────────────────────────────


def _today_title(suffix: str) -> str:
    """오늘 날짜로 동적 브리핑 제목 생성."""
    now = datetime.now(ZoneInfo("Asia/Seoul"))
    return f"{now.month}월 {now.day}일 {suffix}"


_MOCK_MORNING = BriefingResponse(
    type="morning",
    is_mock=True,
    title="모닝 브리핑",  # get 시 동적으로 덮어씀
    summary="FOMC 금리 동결 이후 기술주 반등세가 이어지고 있습니다. NVIDIA 실적 호조로 반도체 섹터 강세, 배당주는 보합세를 유지하고 있습니다.",
    etf_changes=[
        ETFChange(
            ticker="QQQ",
            change_pct=1.2,
            direction="up",
            cause="FOMC 금리 동결 + 기술주 반등",
        ),
        ETFChange(
            ticker="VOO",
            change_pct=0.8,
            direction="up",
            cause="S&P 500 전반적 상승 흐름",
        ),
        ETFChange(
            ticker="SCHD",
            change_pct=-0.3,
            direction="down",
            cause="성장주 대비 배당주 자금 이탈",
        ),
        ETFChange(
            ticker="SOXL",
            change_pct=3.5,
            direction="up",
            cause="NVIDIA 실적 기대감 반영",
        ),
        ETFChange(
            ticker="ARKK",
            change_pct=1.8,
            direction="up",
            cause="금리 하락 기대 + Tesla 매수세",
        ),
        ETFChange(
            ticker="TLT",
            change_pct=0.5,
            direction="up",
            cause="국채 금리 하락으로 채권 가격 상승",
        ),
    ],
    checkpoints=[
        "NVIDIA 실적 발표 후 시간외 거래 반응 확인",
        "FOMC 의사록 세부 내용 분석 필요",
        "유가 $85 돌파에 따른 에너지 섹터 모멘텀 체크",
    ],
    generated_at=datetime.now(timezone.utc).isoformat(),
)

_MOCK_NIGHT = BriefingResponse(
    type="night",
    is_mock=True,
    title="나이트 체크포인트",  # get 시 동적으로 덮어씀
    summary="오늘 하루 시장 마감 후 주요 이벤트를 확인하세요. AI 브리핑이 곧 생성됩니다.",
    etf_changes=[
        ETFChange(
            ticker="QQQ", change_pct=0.0, direction="flat", cause="시장 데이터 로딩 중"
        ),
        ETFChange(
            ticker="VOO", change_pct=0.0, direction="flat", cause="시장 데이터 로딩 중"
        ),
    ],
    checkpoints=[
        "22:30 KST — 미국 시장 정규 거래 시작: ETF 가격 변동 확인",
        "AI 브리핑이 자동 생성되면 실시간 경제 일정이 표시됩니다",
        "설정에서 알림 시간을 변경할 수 있습니다",
    ],
    generated_at=datetime.now(timezone.utc).isoformat(),
)

_FALLBACK_ETFS = ["QQQ", "VOO", "SCHD", "SOXL", "ARKK", "TLT"]


async def _get_dynamic_etf_list() -> list[str]:
    """Supabase 또는 etf_master.json에서 전체 등록 ETF 목록을 조회한다.

    Returns:
        ETF 티커 리스트. 실패 시 fallback 리스트.
    """
    # 1. Supabase에서 조회
    try:
        from services.supabase_client import get_supabase

        sb = get_supabase()
        resp = sb.table("etf_master").select("ticker").execute()
        if resp.data:
            tickers = [row["ticker"] for row in resp.data if row.get("ticker")]
            if tickers:
                return tickers
    except Exception as e:
        logger.warning("Supabase ETF 목록 조회 실패: %s", e)

    # 2. etf_master.json에서 로드
    try:
        from pathlib import Path

        json_path = Path(__file__).resolve().parent.parent / "seeds" / "etf_master.json"
        if json_path.exists():
            with open(json_path, encoding="utf-8") as f:
                data = json.load(f)
            tickers = [etf["ticker"] for etf in data if etf.get("ticker")]
            if tickers:
                return tickers
    except Exception as e:
        logger.warning("etf_master.json 로드 실패: %s", e)

    return _FALLBACK_ETFS


def _get_news_summary() -> str:
    """뉴스 캐시에서 최근 헤드라인 10개를 가져와 프롬프트용 요약을 생성한다.

    Returns:
        뉴스 헤드라인 문자열. 뉴스 0건이면 안내 문구 반환.
    """
    from services.news_service import _news_cache

    if not _news_cache:
        return "최근 수집된 뉴스 없음"

    headlines: list[str] = []
    for article in _news_cache[:10]:
        headline = article.get("headline", "")
        if headline:
            headlines.append(headline)

    if not headlines:
        return "최근 수집된 뉴스 없음"

    return ", ".join(headlines)


def _normalize_tickers(tickers: list[str]) -> list[str]:
    """Normalize tickers while preserving order and uniqueness."""
    normalized: list[str] = []
    seen: set[str] = set()
    for ticker in tickers:
        upper = ticker.strip().upper()
        if upper and upper not in seen:
            normalized.append(upper)
            seen.add(upper)
    return normalized


def _briefing_signature(tickers: list[str]) -> str:
    """Build a stable signature for a personalized ETF set."""
    normalized = _normalize_tickers(tickers)
    return "-".join(normalized) if normalized else "default"


def _daily_cache_key(prefix: str, tickers: list[str]) -> str:
    """Cache key segmented by KST date and ETF signature."""
    today = datetime.now(ZoneInfo("Asia/Seoul")).date().isoformat()
    return f"{prefix}:{today}:{_briefing_signature(tickers)}"


def _to_direction(change_pct: float) -> str:
    """Map change percentage to BriefingResponse direction enum."""
    if change_pct > 0:
        return "up"
    if change_pct < 0:
        return "down"
    return "flat"


def _trim_cause(text: str, max_len: int = 20) -> str:
    """Keep short briefing causes compact and readable."""
    compact = " ".join(text.split())
    if len(compact) <= max_len:
        return compact
    return compact[: max_len - 1].rstrip() + "…"


async def _get_personalized_tickers(device_id: str) -> list[str]:
    """Resolve the ETF set used for a personalized briefing."""
    from services.etf_service import etf_service

    registered = _normalize_tickers(await etf_service.get_registered(device_id))
    if registered:
        return registered[:6]
    return _FALLBACK_ETFS[:4]


async def _build_price_snapshot(tickers: list[str]) -> list[dict]:
    """Build a compact price snapshot for briefing generation."""
    from services.price_service import get_batch_prices, _get_mock_price

    try:
        prices = await asyncio.wait_for(get_batch_prices(tickers[:4]), timeout=5)
        if prices:
            return prices
    except Exception as e:
        logger.warning("브리핑 가격 스냅샷 생성 실패, mock 사용: %s", e)

    return [_get_mock_price(ticker) for ticker in tickers[:4]]


async def _get_news_items_for_tickers(tickers: list[str]) -> list:
    """Load recent news relevant to the target tickers."""
    from services.news_service import news_service

    items = await news_service.get_news_for_etfs(tickers)
    return items[:5]


def _build_price_summary(prices: list[dict]) -> str:
    """Convert ETF prices into a compact prompt summary."""
    if not prices:
        return "가격 데이터 없음"
    rows = []
    for price in prices:
        rows.append(f"{price.get('ticker', '')}: {price.get('change_pct', 0):+.2f}%")
    return ", ".join(rows)


def _build_news_summary_from_items(items: list) -> str:
    """Convert personalized news items into prompt-friendly text."""
    if not items:
        return "관련 뉴스 없음"
    parts = []
    for item in items[:5]:
        source = f"[{item.source}] " if item.source else ""
        parts.append(f"{source}{item.headline}")
    return " | ".join(parts)


async def _build_dynamic_morning_fallback(device_id: str) -> BriefingResponse:
    """Build a personalized non-LLM morning briefing."""
    tickers = await _get_personalized_tickers(device_id)
    prices = await _build_price_snapshot(tickers)
    news_items = await _get_news_items_for_tickers(tickers)

    changes: list[ETFChange] = []
    for price in prices[:4]:
        ticker = str(price.get("ticker", "")).upper()
        related = next(
            (
                item
                for item in news_items
                if any(imp.etf_ticker == ticker for imp in item.impacts)
            ),
            None,
        )
        cause_source = (
            related.headline if related is not None else f"{ticker} 최근 가격 흐름 반영"
        )
        changes.append(
            ETFChange(
                ticker=ticker,
                change_pct=float(price.get("change_pct", 0.0) or 0.0),
                direction=_to_direction(float(price.get("change_pct", 0.0) or 0.0)),
                cause=_trim_cause(cause_source),
            )
        )

    if changes:
        top_mover = max(changes, key=lambda item: abs(item.change_pct))
        summary = (
            f"간밤에는 {top_mover.ticker}가 {top_mover.change_pct:+.2f}%로 가장 크게 움직였습니다. "
            f"{news_items[0].headline if news_items else '사용자 ETF 기준 핵심 뉴스와 가격 변화를 정리했습니다.'}"
        )
    else:
        summary = "간밤 사용자 ETF 기준 핵심 뉴스와 가격 변화를 정리했습니다."

    checkpoints = [item.headline for item in news_items[:3]]
    if not checkpoints:
        checkpoints = [
            "간밤 사용자 ETF 관련 핵심 뉴스 수집 중",
            "다음 장 시작 전 ETF 가격 흐름 점검 필요",
            "푸시 알림으로 신규 영향도를 확인할 수 있습니다",
        ]

    return BriefingResponse(
        type="morning",
        title=_today_title("모닝 브리핑"),
        summary=summary,
        etf_changes=changes,
        checkpoints=checkpoints,
        generated_at=datetime.now(timezone.utc).isoformat(),
        is_mock=False,
    )


class BriefingService:
    """Generates personalized ETF briefings using Gemini API with mock fallback."""

    async def get_morning_briefing(self, device_id: str) -> BriefingResponse:
        """Return morning briefing for the device.

        Never blocks on Gemini API calls. Returns in priority order:
        1. TTL cache (15분)
        2. Last successfully generated briefing (_last_morning_briefing)
        3. Mock data (즉시 반환)

        Args:
            device_id: The requesting device identifier.

        Returns:
            A BriefingResponse with morning briefing content.
        """
        from services.cache import get_cached, set_cached

        tickers = await _get_personalized_tickers(device_id)
        cache_key = _daily_cache_key("briefing_morning", tickers)
        cached = get_cached(cache_key)
        if cached is not None:
            logger.debug("Cache hit for %s", cache_key)
            return cached

        signature = _briefing_signature(tickers)
        stale = _last_morning_briefings.get(signature)
        if stale is not None:
            logger.info(
                "TTL 캐시 만료, personalized stale morning briefing 반환 (%s)",
                signature,
            )
            set_cached(cache_key, stale)
            return stale

        logger.info(
            "개인화 모닝 브리핑 미생성 — dynamic fallback 즉시 반환 (%s)", signature
        )
        fallback = await _build_dynamic_morning_fallback(device_id)
        set_cached(cache_key, fallback)
        _last_morning_briefings[signature] = fallback
        return fallback

    async def get_night_briefing(self, device_id: str) -> BriefingResponse:
        """Return night checkpoint for the device.

        Never blocks on Gemini API calls. Returns in priority order:
        1. TTL cache (15분)
        2. Last successfully generated briefing (_last_night_briefing)
        3. Mock data (즉시 반환)

        Args:
            device_id: The requesting device identifier.

        Returns:
            A BriefingResponse with night checkpoint content.
        """
        from services.cache import get_cached, set_cached

        tickers = await _get_personalized_tickers(device_id)
        cache_key = _daily_cache_key("briefing_night", tickers)
        cached = get_cached(cache_key)
        if cached is not None:
            logger.debug("Cache hit for %s", cache_key)
            return cached

        signature = _briefing_signature(tickers)
        stale = _last_night_briefings.get(signature)
        if stale is not None:
            logger.info(
                "TTL 캐시 만료, personalized stale night briefing 반환 (%s)", signature
            )
            set_cached(cache_key, stale)
            return stale

        logger.info("브리핑 미생성 — mock night briefing 즉시 반환")
        fallback = _MOCK_NIGHT.model_copy(
            update={
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "title": _today_title("나이트 체크포인트"),
            }
        )
        set_cached(cache_key, fallback)
        _last_night_briefings[signature] = fallback
        return fallback

    async def generate_briefing(self, device_id: str) -> BriefingResponse:
        """Manually trigger briefing generation.

        Args:
            device_id: The requesting device identifier.

        Returns:
            A BriefingResponse (morning or night based on time).
        """
        logger.info("Manual briefing generation triggered for device %s", device_id)
        return await self.generate_morning_briefing_background(device_id)

    async def generate_morning_briefing_background(
        self, device_id: str
    ) -> BriefingResponse:
        """실제로 Gemini API를 호출하여 모닝 브리핑을 생성한다.

        스케줄러 또는 수동 트리거에서 호출한다. API 엔드포인트에서 직접 호출하지 않는다.

        Args:
            device_id: The requesting device identifier.

        Returns:
            A BriefingResponse with morning briefing content.
        """
        from services.cache import set_cached

        tickers = await _get_personalized_tickers(device_id)
        signature = _briefing_signature(tickers)
        cache_key = _daily_cache_key("briefing_morning", tickers)
        fallback = await _build_dynamic_morning_fallback(device_id)

        if not settings.GEMINI_API_KEY:
            logger.warning("GEMINI_API_KEY 미설정 — personalized dynamic fallback 반환")
            set_cached(cache_key, fallback)
            _last_morning_briefings[signature] = fallback
            return fallback

        price_summary = _build_price_summary(await _build_price_snapshot(tickers))
        news_summary = _build_news_summary_from_items(
            await _get_news_items_for_tickers(tickers)
        )
        prompt = MORNING_PROMPT.format(
            today_date=datetime.now(ZoneInfo("Asia/Seoul")).date().isoformat(),
            etf_list=", ".join(tickers),
            price_summary=price_summary,
            news_summary=news_summary,
        )
        data = await _call_gemini(prompt)

        if data is None:
            logger.warning("Gemini API 실패 — personalized dynamic fallback 반환")
            set_cached(cache_key, fallback)
            _last_morning_briefings[signature] = fallback
            return fallback

        result = _build_briefing_from_ai(data, "morning")
        if not result.etf_changes:
            result = fallback.model_copy(
                update={"summary": result.summary or fallback.summary}
            )
        _last_morning_briefings[signature] = result
        set_cached(cache_key, result)
        return result

    async def generate_night_briefing_background(
        self, device_id: str
    ) -> BriefingResponse:
        """실제로 Gemini API를 호출하여 나이트 브리핑을 생성한다.

        스케줄러 또는 수동 트리거에서 호출한다. API 엔드포인트에서 직접 호출하지 않는다.

        Args:
            device_id: The requesting device identifier.

        Returns:
            A BriefingResponse with night checkpoint content.
        """
        from services.cache import set_cached

        tickers = await _get_personalized_tickers(device_id)
        signature = _briefing_signature(tickers)
        cache_key = _daily_cache_key("briefing_night", tickers)

        if not settings.GEMINI_API_KEY:
            logger.warning("GEMINI_API_KEY 미설정 — mock 데이터 반환")
            fallback = _MOCK_NIGHT.model_copy(
                update={
                    "generated_at": datetime.now(timezone.utc).isoformat(),
                    "is_mock": True,
                }
            )
            set_cached(cache_key, fallback)
            _last_night_briefings[signature] = fallback
            return fallback

        etf_list = ", ".join(tickers)
        news_summary = _get_news_summary()
        today_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        prompt = NIGHT_PROMPT.format(
            etf_list=etf_list,
            news_summary=news_summary,
            today_date=today_date,
        )
        data = await _call_gemini(prompt)

        if data is None:
            logger.warning("Gemini API 실패 — mock night briefing 반환")
            fallback = _MOCK_NIGHT.model_copy(
                update={
                    "generated_at": datetime.now(timezone.utc).isoformat(),
                    "is_mock": True,
                }
            )
            set_cached(cache_key, fallback)
            _last_night_briefings[signature] = fallback
            return fallback

        result = _build_briefing_from_ai(data, "night")
        _last_night_briefings[signature] = result
        set_cached(cache_key, result)
        return result


briefing_service = BriefingService()
