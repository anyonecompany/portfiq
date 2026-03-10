"""AI 브리핑 생성 서비스 — Claude API 연동."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone

import anthropic

from config import settings
from models.schemas import BriefingResponse, ETFChange
from prompts.briefing import MORNING_PROMPT, NIGHT_PROMPT

logger = logging.getLogger(__name__)

MODEL = "claude-sonnet-4-5-20250929"

_client: anthropic.Anthropic | None = None


def _get_client() -> anthropic.Anthropic:
    """Return a lazily-initialised Anthropic client."""
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    return _client


def _call_claude(prompt: str) -> dict | None:
    """Claude API 호출 + JSON 파싱.

    Args:
        prompt: The formatted prompt to send to Claude.

    Returns:
        Parsed JSON dict on success, None on failure.
    """
    try:
        client = _get_client()
        response = client.messages.create(
            model=MODEL,
            max_tokens=1024,
            messages=[{"role": "user", "content": prompt}],
        )
        text = response.content[0].text
        # Extract JSON from response
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        return json.loads(text.strip())
    except Exception as e:
        logger.error("Claude API 호출 실패: %s", e)
        return None


def _build_briefing_from_claude(data: dict, briefing_type: str) -> BriefingResponse:
    """Convert Claude JSON output into a BriefingResponse.

    Args:
        data: Parsed JSON dict from Claude.
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
                checkpoints.append(f"{time_} — {event}: {impact}" if time_ else f"{event}: {impact}")
            else:
                checkpoints.append(str(cp))

    return BriefingResponse(
        type=briefing_type,
        title=data.get("title", f"{'모닝' if briefing_type == 'morning' else '나이트'} 브리핑"),
        summary=data.get("summary", ""),
        etf_changes=etf_changes,
        checkpoints=checkpoints,
        generated_at=datetime.now(timezone.utc).isoformat(),
    )


# ──────────────────────────────────────────────
# Mock briefing data (fallback)
# ──────────────────────────────────────────────

_MOCK_MORNING = BriefingResponse(
    type="morning",
    title="3월 10일 모닝 브리핑",
    summary="FOMC 금리 동결 이후 기술주 반등세가 이어지고 있습니다. NVIDIA 실적 호조로 반도체 섹터 강세, 배당주는 보합세를 유지하고 있습니다.",
    etf_changes=[
        ETFChange(ticker="QQQ", change_pct=1.2, direction="up", cause="FOMC 금리 동결 + 기술주 반등"),
        ETFChange(ticker="VOO", change_pct=0.8, direction="up", cause="S&P 500 전반적 상승 흐름"),
        ETFChange(ticker="SCHD", change_pct=-0.3, direction="down", cause="성장주 대비 배당주 자금 이탈"),
        ETFChange(ticker="SOXL", change_pct=3.5, direction="up", cause="NVIDIA 실적 기대감 반영"),
        ETFChange(ticker="ARKK", change_pct=1.8, direction="up", cause="금리 하락 기대 + Tesla 매수세"),
        ETFChange(ticker="TLT", change_pct=0.5, direction="up", cause="국채 금리 하락으로 채권 가격 상승"),
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
    title="3월 10일 나이트 체크포인트",
    summary="오늘 하루 기술주 중심 강세 마감. 야간에 발표될 3가지 이벤트에 주목하세요.",
    etf_changes=[
        ETFChange(ticker="QQQ", change_pct=1.5, direction="up", cause="기술주 매수세 지속"),
        ETFChange(ticker="VOO", change_pct=0.9, direction="up", cause="S&P 500 +0.9% 마감"),
        ETFChange(ticker="SOXL", change_pct=4.2, direction="up", cause="반도체 섹터 랠리"),
    ],
    checkpoints=[
        "21:30 — 미국 소비자물가지수(CPI) 발표 예정",
        "22:00 — 연준 이사 월러 연설: 금리 전망 힌트 가능성",
        "익일 장전 — 유럽중앙은행(ECB) 금리 결정 영향 체크",
    ],
    generated_at=datetime.now(timezone.utc).isoformat(),
)

# Default ETF list for mock/fallback
_DEFAULT_ETFS = ["QQQ", "VOO", "SCHD", "SOXL", "ARKK", "TLT"]


class BriefingService:
    """Generates personalized ETF briefings using Claude API with mock fallback."""

    async def get_morning_briefing(self, device_id: str) -> BriefingResponse:
        """Return morning briefing for the device.

        Calls Claude API with the morning prompt. Falls back to mock data
        if the API key is missing or the call fails.

        Args:
            device_id: The requesting device identifier.

        Returns:
            A BriefingResponse with morning briefing content.
        """
        if not settings.ANTHROPIC_API_KEY:
            logger.warning("ANTHROPIC_API_KEY 미설정 — mock 데이터 반환")
            return _MOCK_MORNING.model_copy(
                update={"generated_at": datetime.now(timezone.utc).isoformat()}
            )

        # TODO: fetch device's registered ETFs from DB
        etf_list = ", ".join(_DEFAULT_ETFS)
        # TODO: fetch real news summaries
        news_summary = (
            "FOMC 금리 동결, NVIDIA 분기 실적 매출 260% 급증, "
            "국제유가 WTI $85 돌파, 미 국채 10년물 금리 4.1%로 하락"
        )

        prompt = MORNING_PROMPT.format(etf_list=etf_list, news_summary=news_summary)
        data = _call_claude(prompt)

        if data is None:
            logger.warning("Claude API 실패 — mock morning briefing 반환")
            return _MOCK_MORNING.model_copy(
                update={"generated_at": datetime.now(timezone.utc).isoformat()}
            )

        return _build_briefing_from_claude(data, "morning")

    async def get_night_briefing(self, device_id: str) -> BriefingResponse:
        """Return night checkpoint for the device.

        Calls Claude API with the night prompt. Falls back to mock data
        if the API key is missing or the call fails.

        Args:
            device_id: The requesting device identifier.

        Returns:
            A BriefingResponse with night checkpoint content.
        """
        if not settings.ANTHROPIC_API_KEY:
            logger.warning("ANTHROPIC_API_KEY 미설정 — mock 데이터 반환")
            return _MOCK_NIGHT.model_copy(
                update={"generated_at": datetime.now(timezone.utc).isoformat()}
            )

        etf_list = ", ".join(_DEFAULT_ETFS)
        news_summary = (
            "오늘 밤 CPI 발표 예정, 연준 이사 월러 연설 예정, "
            "유럽중앙은행 금리 결정 대기 중"
        )

        prompt = NIGHT_PROMPT.format(etf_list=etf_list, news_summary=news_summary)
        data = _call_claude(prompt)

        if data is None:
            logger.warning("Claude API 실패 — mock night briefing 반환")
            return _MOCK_NIGHT.model_copy(
                update={"generated_at": datetime.now(timezone.utc).isoformat()}
            )

        return _build_briefing_from_claude(data, "night")

    async def generate_briefing(self, device_id: str) -> BriefingResponse:
        """Manually trigger briefing generation.

        Delegates to get_morning_briefing by default. In production,
        this could determine the appropriate briefing type based on
        current time (KST).

        Args:
            device_id: The requesting device identifier.

        Returns:
            A BriefingResponse (morning or night based on time).
        """
        logger.info("Manual briefing generation triggered for device %s", device_id)
        return await self.get_morning_briefing(device_id)


briefing_service = BriefingService()
