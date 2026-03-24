"""일간 메트릭 집계 Job.

매일 01:00 KST (16:00 UTC)에 실행되어 전일 이벤트를 집계한다.
DAU, 온보딩 전환율, D1/D7/D30 리텐션, 푸시 CTR, 아하 모먼트,
세션 지표 등을 계산하여 daily_metrics 테이블에 UPSERT한다.
"""

import logging
import os
import sys
from datetime import date, timedelta
from typing import Any

logger = logging.getLogger(__name__)


def _notify_failure(error_msg: str) -> None:
    """배치 실패 시 Slack 알림 전송.

    Args:
        error_msg: 에러 메시지.
    """
    try:
        sys.path.insert(0, os.path.expanduser("~/ai-dev-team"))
        from integrations.slack.slack_notifier import send_slack

        send_slack(f"⚠️ 집계 배치 실패: {error_msg}")
    except Exception:
        pass  # Slack 미사용 환경에서도 크래시 방지


def _safe_division(numerator: int, denominator: int) -> float:
    """안전한 나눗셈. 분모 0이면 0.0 반환.

    Args:
        numerator: 분자.
        denominator: 분모.

    Returns:
        나눗셈 결과 (소수점 4자리 반올림).
    """
    if denominator == 0:
        return 0.0
    return round(numerator / denominator, 4)


async def aggregate_daily_metrics(target_date: date | None = None) -> dict[str, Any]:
    """일간 메트릭을 집계한다.

    Supabase events 테이블에서 전일 데이터를 읽어 DAU, 온보딩 전환율,
    리텐션, 푸시 CTR, 아하 모먼트, 세션 지표를 계산하고 daily_metrics에 UPSERT한다.

    Args:
        target_date: 집계 대상 날짜 (기본: 어제).

    Returns:
        집계 결과 딕셔너리.
    """
    if target_date is None:
        target_date = date.today() - timedelta(days=1)

    date_str = target_date.isoformat()
    next_date_str = (target_date + timedelta(days=1)).isoformat()

    try:
        from services.supabase_client import get_supabase

        sb = get_supabase()

        # ── DAU: session_started 이벤트의 고유 device_id 수 ──
        session_resp = (
            sb.table("events")
            .select("device_id")
            .eq("event_name", "session_started")
            .gte("event_timestamp", date_str)
            .lt("event_timestamp", next_date_str)
            .execute()
        )
        session_devices = set(e["device_id"] for e in (session_resp.data or []))
        dau = len(session_devices)

        # ── 신규 유저: 당일 처음 app_opened한 디바이스 ──
        app_opened_resp = (
            sb.table("events")
            .select("device_id")
            .eq("event_name", "app_opened")
            .gte("event_timestamp", date_str)
            .lt("event_timestamp", next_date_str)
            .execute()
        )
        new_devices = set(e["device_id"] for e in (app_opened_resp.data or []))
        new_users = len(new_devices)

        # ── 온보딩 전환율: onboarding_completed / app_opened (당일 신규) ──
        onboarding_resp = (
            sb.table("events")
            .select("device_id")
            .eq("event_name", "onboarding_completed")
            .gte("event_timestamp", date_str)
            .lt("event_timestamp", next_date_str)
            .execute()
        )
        onboarding_devices = set(e["device_id"] for e in (onboarding_resp.data or []))
        # 당일 신규 중 온보딩 완료한 비율
        onboarding_new = onboarding_devices & new_devices
        onboarding_conversion = _safe_division(len(onboarding_new), new_users)

        # ── D1/D7/D30 리텐션 ──
        d1_retention = await _calc_retention(sb, target_date, 1)
        d7_retention = await _calc_retention(sb, target_date, 7)
        d30_retention = await _calc_retention(sb, target_date, 30)

        # ── 푸시 CTR: morning/night ──
        morning_push_ctr = await _calc_push_ctr(sb, target_date, "morning")
        night_push_ctr = await _calc_push_ctr(sb, target_date, "night")

        # ── 아하 모먼트: aha_moment_feed_viewed / etf_registered ──
        aha_resp = (
            sb.table("events")
            .select("device_id")
            .eq("event_name", "aha_moment_feed_viewed")
            .gte("event_timestamp", date_str)
            .lt("event_timestamp", next_date_str)
            .execute()
        )
        aha_devices = set(e["device_id"] for e in (aha_resp.data or []))

        etf_reg_resp = (
            sb.table("events")
            .select("device_id")
            .eq("event_name", "etf_registered")
            .gte("event_timestamp", date_str)
            .lt("event_timestamp", next_date_str)
            .execute()
        )
        etf_reg_devices = set(e["device_id"] for e in (etf_reg_resp.data or []))
        aha_moment_rate = _safe_division(len(aha_devices), len(etf_reg_devices))

        # ── 세션 지표: 평균 세션 시간 + 유저당 세션 수 ──
        avg_session_duration, sessions_per_user = await _calc_session_metrics(
            sb, target_date
        )

        metrics = {
            "date": date_str,
            "dau": dau,
            "new_users": new_users,
            "onboarding_conversion": onboarding_conversion,
            "d1_retention": d1_retention,
            "d7_retention": d7_retention,
            "d30_retention": d30_retention,
            "morning_push_ctr": morning_push_ctr,
            "night_push_ctr": night_push_ctr,
            "aha_moment_rate": aha_moment_rate,
            "avg_session_duration": avg_session_duration,
            "sessions_per_user": sessions_per_user,
        }

        # UPSERT into daily_metrics
        sb.table("daily_metrics").upsert(metrics, on_conflict="date").execute()

        logger.info(
            "일간 메트릭 집계 완료: %s → DAU=%d, 신규=%d", date_str, dau, new_users
        )
        return metrics

    except Exception as e:
        error_msg = f"{date_str} 집계 실패: {e}"
        logger.warning("일간 메트릭 집계 실패: %s", e)
        _notify_failure(error_msg)
        return {"date": date_str, "error": str(e)}


async def _calc_retention(sb: Any, target_date: date, days_ago: int) -> float:
    """D-N 리텐션 계산.

    N일 전에 session_started한 디바이스 중 오늘(target_date)에도
    session_started한 디바이스의 비율.

    Args:
        sb: Supabase 클라이언트.
        target_date: 집계 대상일.
        days_ago: 리텐션 기간 (1, 7, 30).

    Returns:
        리텐션 비율 (0.0 ~ 1.0).
    """
    cohort_date = target_date - timedelta(days=days_ago)
    cohort_str = cohort_date.isoformat()
    cohort_next_str = (cohort_date + timedelta(days=1)).isoformat()

    target_str = target_date.isoformat()
    target_next_str = (target_date + timedelta(days=1)).isoformat()

    # N일 전 세션 시작 디바이스
    cohort_resp = (
        sb.table("events")
        .select("device_id")
        .eq("event_name", "session_started")
        .gte("event_timestamp", cohort_str)
        .lt("event_timestamp", cohort_next_str)
        .execute()
    )
    cohort_devices = set(e["device_id"] for e in (cohort_resp.data or []))

    if not cohort_devices:
        return 0.0

    # 오늘 세션 시작 디바이스
    today_resp = (
        sb.table("events")
        .select("device_id")
        .eq("event_name", "session_started")
        .gte("event_timestamp", target_str)
        .lt("event_timestamp", target_next_str)
        .execute()
    )
    today_devices = set(e["device_id"] for e in (today_resp.data or []))

    retained = cohort_devices & today_devices
    return _safe_division(len(retained), len(cohort_devices))


async def _calc_push_ctr(sb: Any, target_date: date, push_type: str) -> float:
    """푸시 CTR 계산: push_tapped / push_received.

    Args:
        sb: Supabase 클라이언트.
        target_date: 집계 대상일.
        push_type: "morning" 또는 "night".

    Returns:
        CTR (0.0 ~ 1.0).
    """
    date_str = target_date.isoformat()
    next_date_str = (target_date + timedelta(days=1)).isoformat()

    received_resp = (
        sb.table("events")
        .select("device_id")
        .eq("event_name", "push_received")
        .gte("event_timestamp", date_str)
        .lt("event_timestamp", next_date_str)
        .execute()
    )
    # push_type 필터: properties에 push_type이 저장되어 있다고 가정
    received = [
        e
        for e in (received_resp.data or [])
        if (e.get("properties") or {}).get("push_type") == push_type
    ]

    tapped_resp = (
        sb.table("events")
        .select("device_id")
        .eq("event_name", "push_tapped")
        .gte("event_timestamp", date_str)
        .lt("event_timestamp", next_date_str)
        .execute()
    )
    tapped = [
        e
        for e in (tapped_resp.data or [])
        if (e.get("properties") or {}).get("push_type") == push_type
    ]

    return _safe_division(len(tapped), len(received))


async def _calc_session_metrics(sb: Any, target_date: date) -> tuple[int, float]:
    """세션 지표 계산: 평균 세션 시간(초) + 유저당 세션 수.

    session_metrics 테이블에서 해당 일자의 세션 데이터를 조회한다.
    session_metrics가 없으면 events 테이블에서 추정한다.

    Args:
        sb: Supabase 클라이언트.
        target_date: 집계 대상일.

    Returns:
        (avg_session_duration_seconds, sessions_per_user).
    """
    date_str = target_date.isoformat()
    next_date_str = (target_date + timedelta(days=1)).isoformat()

    try:
        sess_resp = (
            sb.table("session_metrics")
            .select("device_id, duration_seconds")
            .gte("started_at", date_str)
            .lt("started_at", next_date_str)
            .execute()
        )
        sessions = sess_resp.data or []
    except Exception:
        # session_metrics 테이블이 아직 없을 수 있음
        sessions = []

    if not sessions:
        # fallback: session_started 이벤트 카운트로 추정
        fallback_resp = (
            sb.table("events")
            .select("device_id")
            .eq("event_name", "session_started")
            .gte("event_timestamp", date_str)
            .lt("event_timestamp", next_date_str)
            .execute()
        )
        raw_events = fallback_resp.data or []
        if not raw_events:
            return 0, 0.0
        devices = set(e["device_id"] for e in raw_events)
        return 0, round(len(raw_events) / len(devices), 2)

    total_duration = sum(s.get("duration_seconds", 0) for s in sessions)
    avg_duration = total_duration // len(sessions) if sessions else 0

    devices = set(s["device_id"] for s in sessions)
    sessions_per_user = round(len(sessions) / len(devices), 2) if devices else 0.0

    return avg_duration, sessions_per_user
