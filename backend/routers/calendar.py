"""Calendar router — economic calendar events API."""

from __future__ import annotations

import logging
from datetime import date, timedelta

from fastapi import APIRouter, Query

from services.calendar_service import calendar_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/events")
async def get_calendar_events(
    from_date: date = Query(
        alias="from",
        default=None,
        description="조회 시작 날짜 (YYYY-MM-DD). 기본값: 이번 달 1일.",
    ),
    to_date: date = Query(
        alias="to",
        default=None,
        description="조회 종료 날짜 (YYYY-MM-DD). 기본값: 이번 달 마지막 날.",
    ),
) -> dict:
    """경제 캘린더 이벤트 목록을 반환한다.

    Args:
        from_date: 조회 시작 날짜. 미입력 시 이번 달 1일.
        to_date: 조회 종료 날짜. 미입력 시 이번 달 마지막 날.

    Returns:
        이벤트 목록과 메타 정보.
    """
    today = date.today()

    if from_date is None:
        from_date = date(today.year, today.month, 1)
    if to_date is None:
        # 이번 달 마지막 날
        if today.month == 12:
            to_date = date(today.year + 1, 1, 1) - timedelta(days=1)
        else:
            to_date = date(today.year, today.month + 1, 1) - timedelta(days=1)

    # 최대 90일 제한 (과도한 데이터 방지)
    if (to_date - from_date).days > 90:
        to_date = from_date + timedelta(days=90)

    events = calendar_service.get_events(from_date, to_date)

    return {
        "events": [e.to_dict() for e in events],
        "total": len(events),
        "from": from_date.isoformat(),
        "to": to_date.isoformat(),
    }


@router.get("/upcoming")
async def get_upcoming_events(
    days: int = Query(
        default=7,
        ge=1,
        le=30,
        description="조회 기간 (일). 기본 7일, 최대 30일.",
    ),
) -> dict:
    """오늘부터 N일 이내의 경제 이벤트를 반환한다.

    편의 엔드포인트로, /events에 from=today, to=today+days 호출과 동일.

    Args:
        days: 조회 기간 (일).

    Returns:
        이벤트 목록과 메타 정보.
    """
    today = date.today()
    to_date = today + timedelta(days=days)

    events = calendar_service.get_upcoming(days)

    return {
        "events": [e.to_dict() for e in events],
        "total": len(events),
        "from": today.isoformat(),
        "to": to_date.isoformat(),
    }
