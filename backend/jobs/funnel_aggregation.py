"""퍼널 코호트 집계 Job.

매일 01:30 KST (16:30 UTC)에 실행되어 7단계 온보딩 퍼널을
코호트별(일자별)로 집계한다.
"""

import logging
import os
import sys
from datetime import date, timedelta
from typing import Any

logger = logging.getLogger(__name__)

# 7단계 퍼널 정의 (순서 중요)
FUNNEL_STEPS: list[tuple[int, str, str]] = [
    (1, "app_opened", "앱 열기"),
    (2, "onboarding_started", "온보딩 시작"),
    (3, "etf_registered", "ETF 등록"),
    (4, "aha_moment_feed_viewed", "아하 모먼트 피드 조회"),
    (5, "push_permission_granted", "푸시 권한 허용"),
    (6, "onboarding_completed", "온보딩 완료"),
    (7, "day_n_return_7", "D7 리텐션"),
]


def _notify_failure(error_msg: str) -> None:
    """배치 실패 시 Slack 알림 전송.

    Args:
        error_msg: 에러 메시지.
    """
    try:
        sys.path.insert(0, os.path.expanduser("~/ai-dev-team"))
        from integrations.slack.slack_notifier import send_slack

        send_slack(f"⚠️ 퍼널 집계 배치 실패: {error_msg}")
    except Exception:
        pass


def _safe_division(numerator: int, denominator: int) -> float:
    """안전한 나눗셈.

    Args:
        numerator: 분자.
        denominator: 분모.

    Returns:
        나눗셈 결과 (소수점 4자리 반올림).
    """
    if denominator == 0:
        return 0.0
    return round(numerator / denominator, 4)


async def aggregate_funnel_cohort(
    target_date: date | None = None,
) -> list[dict[str, Any]]:
    """퍼널 코호트 집계.

    target_date 기준으로 각 퍼널 단계별 유저 수, 이전 단계 대비 전환율,
    최상위 대비 전환율을 계산하여 funnel_cohorts 테이블에 UPSERT한다.

    Args:
        target_date: 집계 대상 날짜 (기본: 어제).

    Returns:
        퍼널 단계별 집계 결과 리스트.
    """
    if target_date is None:
        target_date = date.today() - timedelta(days=1)

    date_str = target_date.isoformat()
    next_date_str = (target_date + timedelta(days=1)).isoformat()

    try:
        from services.supabase_client import get_supabase

        sb = get_supabase()

        # 각 단계별 device_id 집합 수집
        step_devices: dict[str, set[str]] = {}

        for step_order, event_name, _label in FUNNEL_STEPS:
            if event_name == "day_n_return_7":
                # D7 리텐션: 7일 전 app_opened 디바이스 중 오늘 세션이 있는 디바이스
                devices = await _get_d7_return_devices(sb, target_date)
            else:
                resp = (
                    sb.table("events")
                    .select("device_id")
                    .eq("event_name", event_name)
                    .gte("event_timestamp", date_str)
                    .lt("event_timestamp", next_date_str)
                    .execute()
                )
                devices = set(e["device_id"] for e in (resp.data or []))

            step_devices[event_name] = devices

        # 퍼널 결과 계산
        results: list[dict[str, Any]] = []
        top_count = len(step_devices.get("app_opened", set()))

        prev_count = top_count
        for step_order, event_name, _label in FUNNEL_STEPS:
            user_count = len(step_devices.get(event_name, set()))
            conversion_from_prev = _safe_division(user_count, prev_count)
            conversion_from_top = _safe_division(user_count, top_count)

            row = {
                "cohort_date": date_str,
                "step": event_name,
                "step_order": step_order,
                "user_count": user_count,
                "conversion_from_prev": conversion_from_prev,
                "conversion_from_top": conversion_from_top,
            }
            results.append(row)
            prev_count = user_count if user_count > 0 else prev_count

        # UPSERT into funnel_cohorts
        if results:
            sb.table("funnel_cohorts").upsert(
                results, on_conflict="cohort_date,step"
            ).execute()

        logger.info(
            "퍼널 코호트 집계 완료: %s → top=%d, bottom=%d",
            date_str,
            top_count,
            len(step_devices.get("day_n_return_7", set())),
        )
        return results

    except Exception as e:
        error_msg = f"{date_str} 퍼널 집계 실패: {e}"
        logger.warning("퍼널 코호트 집계 실패: %s", e)
        _notify_failure(error_msg)
        return []


async def _get_d7_return_devices(sb: Any, target_date: date) -> set[str]:
    """D7 리턴 디바이스 계산.

    7일 전에 app_opened한 디바이스 중 target_date에 session_started한 디바이스.

    Args:
        sb: Supabase 클라이언트.
        target_date: 집계 대상일.

    Returns:
        D7 리턴 디바이스 ID 집합.
    """
    cohort_date = target_date - timedelta(days=7)
    cohort_str = cohort_date.isoformat()
    cohort_next_str = (cohort_date + timedelta(days=1)).isoformat()

    target_str = target_date.isoformat()
    target_next_str = (target_date + timedelta(days=1)).isoformat()

    # 7일 전 app_opened 디바이스
    cohort_resp = (
        sb.table("events")
        .select("device_id")
        .eq("event_name", "app_opened")
        .gte("event_timestamp", cohort_str)
        .lt("event_timestamp", cohort_next_str)
        .execute()
    )
    cohort_devices = set(e["device_id"] for e in (cohort_resp.data or []))

    if not cohort_devices:
        return set()

    # 오늘 session_started 디바이스
    today_resp = (
        sb.table("events")
        .select("device_id")
        .eq("event_name", "session_started")
        .gte("event_timestamp", target_str)
        .lt("event_timestamp", target_next_str)
        .execute()
    )
    today_devices = set(e["device_id"] for e in (today_resp.data or []))

    return cohort_devices & today_devices
