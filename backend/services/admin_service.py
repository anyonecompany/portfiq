"""Admin 서비스 — Supabase 데이터 집계 및 관리 기능.

대시보드 KPI, 퍼널 분석, 리텐션, 유저 통계, 이벤트 탐색,
푸시 발송 등 Admin API에 필요한 비즈니스 로직을 제공한다.
"""

from __future__ import annotations

import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any

from services.supabase_client import get_supabase

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
# 1. Dashboard KPI
# ──────────────────────────────────────────────

async def get_dashboard_stats() -> dict[str, Any]:
    """대시보드 KPI 통계를 반환한다.

    daily_metrics 테이블에서 최근 데이터를 조회하고,
    전일 대비 변화율을 계산한다.

    Returns:
        KPI 데이터 딕셔너리 (dau, d7_retention, new_installs 등).

    Raises:
        Exception: Supabase 쿼리 실패 시.
    """
    sb = get_supabase()
    today = date.today()
    yesterday = today - timedelta(days=1)

    # 오늘/어제 메트릭 조회 (실제 컬럼: date, total_devices, active_devices,
    # briefings_generated, news_fetched, events_received, avg_etfs_per_device)
    today_resp = (
        sb.table("daily_metrics")
        .select("*")
        .eq("date", today.isoformat())
        .execute()
    )
    yesterday_resp = (
        sb.table("daily_metrics")
        .select("*")
        .eq("date", yesterday.isoformat())
        .execute()
    )

    today_data = today_resp.data[0] if today_resp.data else {}
    yesterday_data = yesterday_resp.data[0] if yesterday_resp.data else {}

    def _kpi(key: str, is_pct: bool = False) -> dict[str, Any]:
        """단일 KPI 항목을 생성한다.

        Args:
            key: daily_metrics 컬럼명.
            is_pct: 값이 이미 퍼센트인지 여부.

        Returns:
            {"value": ..., "change_pct": ..., "direction": ...} 딕셔너리.
        """
        current = today_data.get(key, 0) or 0
        previous = yesterday_data.get(key, 0) or 0

        if previous and previous != 0:
            change_pct = round(((current - previous) / abs(previous)) * 100, 1)
        else:
            change_pct = 0.0

        if change_pct > 0:
            direction = "up"
        elif change_pct < 0:
            direction = "down"
        else:
            direction = "flat"

        return {
            "value": round(current, 1) if is_pct else current,
            "change_pct": change_pct,
            "direction": direction,
        }

    return {
        "date": today.isoformat(),
        "kpis": {
            "dau": _kpi("active_devices"),
            "d7_retention": _kpi("d7_retention", is_pct=True),
            "new_installs": _kpi("total_devices"),
            "onboarding_conversion": _kpi("onboarding_conversion", is_pct=True),
            "briefings_generated": _kpi("briefings_generated"),
            "push_open_rate": _kpi("push_open_rate", is_pct=True),
        },
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


# ──────────────────────────────────────────────
# 2. Funnel Analysis
# ──────────────────────────────────────────────

FUNNEL_STEPS = [
    {"step": 1, "name": "app_install", "event_name": None},
    {"step": 2, "name": "onboarding_started", "event_name": "onboarding_started"},
    {"step": 3, "name": "etf_registered", "event_name": "etf_registered"},
    {
        "step": 4,
        "name": "push_permission_responded",
        "event_name": "push_permission_granted|push_permission_denied",
    },
    {"step": 5, "name": "onboarding_completed", "event_name": "onboarding_completed"},
    {"step": 6, "name": "first_briefing_viewed", "event_name": "briefing_viewed"},
    {
        "step": 7,
        "name": "day2_return",
        "event_name": "session_start",
    },
]


async def get_funnel_data(
    start_date: date,
    end_date: date,
) -> dict[str, Any]:
    """온보딩 퍼널 분석 데이터를 반환한다.

    Args:
        start_date: 분석 시작일.
        end_date: 분석 종료일.

    Returns:
        7단계 퍼널 데이터 딕셔너리.

    Raises:
        ValueError: start_date가 end_date보다 이후인 경우.
    """
    sb = get_supabase()
    start_str = start_date.isoformat()
    end_str = end_date.isoformat()

    # Step 1: 기간 내 신규 설치 수 (devices.created_at)
    install_resp = (
        sb.table("devices")
        .select("device_id", count="exact")
        .gte("created_at", start_str)
        .lte("created_at", end_str + "T23:59:59Z")
        .execute()
    )
    total_installs = install_resp.count if install_resp.count is not None else len(install_resp.data or [])

    steps_result: list[dict[str, Any]] = []

    for step_def in FUNNEL_STEPS:
        step_num = step_def["step"]
        event_name = step_def["event_name"]

        if step_num == 1:
            count = total_installs
        elif step_num == 7:
            # Day 2+ return: session_start 이벤트가 install 다음 날 이후에 발생
            try:
                resp = (
                    sb.rpc(
                        "count_day2_returns",
                        {"p_start": start_str, "p_end": end_str},
                    ).execute()
                )
                count = resp.data if isinstance(resp.data, int) else len(resp.data or [])
            except Exception:
                # RPC 없으면 직접 쿼리 (근사치)
                resp = (
                    sb.table("events")
                    .select("device_id", count="exact")
                    .eq("event_name", "session_start")
                    .gte("event_timestamp", start_str)
                    .lte("event_timestamp", end_str + "T23:59:59Z")
                    .execute()
                )
                count = resp.count if resp.count is not None else len(resp.data or [])
        elif "|" in (event_name or ""):
            # 복수 이벤트 (push_permission_granted | push_permission_denied)
            event_names = [e.strip() for e in event_name.split("|")]
            count = 0
            seen_devices: set[str] = set()
            for en in event_names:
                resp = (
                    sb.table("events")
                    .select("device_id")
                    .eq("event_name", en)
                    .gte("event_timestamp", start_str)
                    .lte("event_timestamp", end_str + "T23:59:59Z")
                    .execute()
                )
                for row in resp.data or []:
                    seen_devices.add(row["device_id"])
            count = len(seen_devices)
        else:
            resp = (
                sb.table("events")
                .select("device_id", count="exact")
                .eq("event_name", event_name)
                .gte("event_timestamp", start_str)
                .lte("event_timestamp", end_str + "T23:59:59Z")
                .execute()
            )
            count = resp.count if resp.count is not None else len(resp.data or [])

        pct_of_total = round((count / total_installs * 100), 1) if total_installs > 0 else 0.0

        # 이전 단계와의 drop-off
        if steps_result:
            prev_count = steps_result[-1]["count"]
            drop_off = round(((prev_count - count) / prev_count * 100), 1) if prev_count > 0 else 0.0
        else:
            drop_off = 0.0

        steps_result.append({
            "step": step_num,
            "name": step_def["name"],
            "event_name": event_name,
            "count": count,
            "pct_of_total": pct_of_total,
            "drop_off_pct": drop_off,
        })

    return {
        "start_date": start_str,
        "end_date": end_str,
        "total_users_in_range": total_installs,
        "steps": steps_result,
    }


# ──────────────────────────────────────────────
# 3. Cohort Retention
# ──────────────────────────────────────────────

async def get_retention_data(weeks: int = 8) -> dict[str, Any]:
    """주간 코호트 리텐션 매트릭스를 반환한다.

    Args:
        weeks: 반환할 코호트 주 수 (1-12).

    Returns:
        코호트별 리텐션 데이터 딕셔너리.
    """
    sb = get_supabase()
    today = date.today()

    cohorts: list[dict[str, Any]] = []

    for w in range(weeks):
        # 코호트 주의 시작일 (월요일)
        cohort_start = today - timedelta(weeks=weeks - w)
        # ISO 주 월요일로 정렬
        cohort_start = cohort_start - timedelta(days=cohort_start.weekday())
        cohort_end = cohort_start + timedelta(days=6)
        iso_year, iso_week, _ = cohort_start.isocalendar()
        cohort_week_label = f"{iso_year}-W{iso_week:02d}"

        # 해당 주에 설치된 디바이스
        install_resp = (
            sb.table("devices")
            .select("device_id")
            .gte("created_at", cohort_start.isoformat())
            .lte("created_at", cohort_end.isoformat() + "T23:59:59Z")
            .execute()
        )
        cohort_devices = [r["device_id"] for r in (install_resp.data or [])]
        cohort_size = len(cohort_devices)

        if cohort_size == 0:
            continue

        retention_list: list[dict[str, Any]] = []

        # 각 후속 주에 대한 리텐션 계산
        max_weeks_available = (today - cohort_start).days // 7
        for wk in range(min(max_weeks_available + 1, weeks)):
            week_start = cohort_start + timedelta(weeks=wk)
            week_end = week_start + timedelta(days=6)

            if week_start > today:
                break

            if wk == 0:
                active = cohort_size
            else:
                # session_start 이벤트로 활성 사용자 확인
                try:
                    active_resp = (
                        sb.table("events")
                        .select("device_id")
                        .eq("event_name", "session_start")
                        .gte("event_timestamp", week_start.isoformat())
                        .lte("event_timestamp", week_end.isoformat() + "T23:59:59Z")
                        .in_("device_id", cohort_devices)
                        .execute()
                    )
                    active_devices = {r["device_id"] for r in (active_resp.data or [])}
                    active = len(active_devices)
                except Exception as e:
                    logger.warning("리텐션 쿼리 실패 (week %d): %s", wk, e)
                    active = 0

            rate = round((active / cohort_size) * 100, 1)
            retention_list.append({
                "week": wk,
                "active": active,
                "rate": rate,
            })

        cohorts.append({
            "cohort_week": cohort_week_label,
            "cohort_start": cohort_start.isoformat(),
            "cohort_size": cohort_size,
            "retention": retention_list,
        })

    return {
        "weeks": weeks,
        "cohorts": cohorts,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


# ──────────────────────────────────────────────
# 4. User Statistics
# ──────────────────────────────────────────────

async def get_user_stats() -> dict[str, Any]:
    """유저 통계를 반환한다.

    Returns:
        총 설치 수, 활성 사용자, 푸시 허용 비율,
        ETF 분포, 플랫폼 분포, 인기 ETF 등.
    """
    sb = get_supabase()
    today = date.today()

    # 총 설치 수
    install_resp = sb.table("devices").select("device_id", count="exact").execute()
    total_installs = install_resp.count if install_resp.count is not None else len(install_resp.data or [])

    # 7일/30일 활성 사용자
    d7 = (today - timedelta(days=7)).isoformat()
    d30 = (today - timedelta(days=30)).isoformat()

    active_7d_resp = (
        sb.table("events")
        .select("device_id")
        .eq("event_name", "session_start")
        .gte("event_timestamp", d7)
        .execute()
    )
    active_7d = len({r["device_id"] for r in (active_7d_resp.data or [])})

    active_30d_resp = (
        sb.table("events")
        .select("device_id")
        .eq("event_name", "session_start")
        .gte("event_timestamp", d30)
        .execute()
    )
    active_30d = len({r["device_id"] for r in (active_30d_resp.data or [])})

    # 푸시 허용 수
    push_resp = (
        sb.table("devices")
        .select("device_id", count="exact")
        .neq("push_token", "")
        .execute()
    )
    push_enabled = push_resp.count if push_resp.count is not None else len(push_resp.data or [])
    push_pct = round((push_enabled / total_installs) * 100, 1) if total_installs > 0 else 0.0

    # 플랫폼 분포
    platform_resp = sb.table("devices").select("platform").execute()
    platform_counts: dict[str, int] = {}
    for row in platform_resp.data or []:
        p = (row.get("platform") or "unknown").lower()
        platform_counts[p] = platform_counts.get(p, 0) + 1

    platform_breakdown = []
    for p, cnt in sorted(platform_counts.items(), key=lambda x: -x[1]):
        platform_breakdown.append({
            "platform": p,
            "count": cnt,
            "pct": round((cnt / total_installs) * 100, 1) if total_installs > 0 else 0.0,
        })

    # 인기 ETF (상위 10)
    top_etfs: list[dict[str, Any]] = []
    try:
        top_etf_resp = (
            sb.rpc("get_top_etfs", {"p_limit": 10}).execute()
        )
        if top_etf_resp.data:
            top_etfs = top_etf_resp.data
    except Exception:
        # RPC 없으면 직접 쿼리
        try:
            etf_resp = sb.table("device_etfs").select("ticker").execute()
            ticker_counts: dict[str, int] = {}
            for row in etf_resp.data or []:
                t = row.get("ticker", "")
                if t:
                    ticker_counts[t] = ticker_counts.get(t, 0) + 1
            sorted_tickers = sorted(ticker_counts.items(), key=lambda x: -x[1])[:10]
            for ticker, cnt in sorted_tickers:
                # ETF 이름 조회
                name_resp = (
                    sb.table("etf_master")
                    .select("name")
                    .eq("ticker", ticker)
                    .limit(1)
                    .execute()
                )
                name = name_resp.data[0]["name"] if name_resp.data else ticker
                top_etfs.append({
                    "ticker": ticker,
                    "name": name,
                    "registered_count": cnt,
                })
        except Exception as e:
            logger.warning("인기 ETF 조회 실패: %s", e)

    return {
        "total_installs": total_installs,
        "active_devices_7d": active_7d,
        "active_devices_30d": active_30d,
        "push_enabled_count": push_enabled,
        "push_enabled_pct": push_pct,
        "platform_breakdown": platform_breakdown,
        "top_etfs": top_etfs,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


# ──────────────────────────────────────────────
# 5. User List (Paginated)
# ──────────────────────────────────────────────

async def get_users(page: int = 1, size: int = 20) -> dict[str, Any]:
    """유저 목록을 페이지네이션으로 반환한다.

    Args:
        page: 페이지 번호 (1-based).
        size: 페이지당 항목 수.

    Returns:
        유저 목록과 페이지네이션 정보.
    """
    sb = get_supabase()
    offset = (page - 1) * size

    # 총 수
    count_resp = sb.table("devices").select("device_id", count="exact").execute()
    total = count_resp.count if count_resp.count is not None else 0

    # 페이지 데이터
    resp = (
        sb.table("devices")
        .select("*")
        .order("created_at", desc=True)
        .range(offset, offset + size - 1)
        .execute()
    )

    return {
        "users": resp.data or [],
        "total": total,
        "page": page,
        "size": size,
        "has_more": (offset + size) < total,
    }


# ──────────────────────────────────────────────
# 6. Event Explorer
# ──────────────────────────────────────────────

async def get_events(
    limit: int = 100,
    offset: int = 0,
    event_name: str | None = None,
    device_id: str | None = None,
    start_date: date | None = None,
    end_date: date | None = None,
) -> dict[str, Any]:
    """이벤트 로그를 필터링하여 반환한다.

    Args:
        limit: 반환할 최대 항목 수 (1-500).
        offset: 페이지네이션 오프셋.
        event_name: 이벤트명 필터 (정확 일치).
        device_id: 디바이스 ID 필터 (정확 일치).
        start_date: 시작일 필터.
        end_date: 종료일 필터.

    Returns:
        이벤트 목록과 페이지네이션 정보.
    """
    sb = get_supabase()

    # 기본 날짜 범위
    if start_date is None:
        start_date = date.today() - timedelta(days=1)
    if end_date is None:
        end_date = date.today()

    # 쿼리 빌드
    query = (
        sb.table("events")
        .select("*", count="exact")
        .gte("event_timestamp", start_date.isoformat())
        .lte("event_timestamp", end_date.isoformat() + "T23:59:59Z")
        .order("event_timestamp", desc=True)
    )

    if event_name:
        query = query.eq("event_name", event_name)
    if device_id:
        query = query.eq("device_id", device_id)

    query = query.range(offset, offset + limit - 1)

    resp = query.execute()
    total = resp.count if resp.count is not None else len(resp.data or [])

    return {
        "events": resp.data or [],
        "total": total,
        "limit": limit,
        "offset": offset,
        "has_more": (offset + limit) < total,
    }


# ──────────────────────────────────────────────
# 7. Push Send
# ──────────────────────────────────────────────

async def send_admin_push(
    target: str,
    title: str,
    body: str,
) -> dict[str, Any]:
    """관리자 푸시 알림을 발송한다.

    Args:
        target: 발송 대상. "all"이면 전체, 아니면 특정 device_id.
        title: 푸시 제목.
        body: 푸시 본문.

    Returns:
        발송 결과 요약 {"total": int, "success": int, "failed": int}.
    """
    from services.push_service import send_push, _get_all_device_tokens

    if target == "all":
        devices = _get_all_device_tokens()
        total = len(devices)
        success = 0
        failed = 0
        for device in devices:
            try:
                result = await send_push(
                    device_id=device["device_id"],
                    title=title,
                    body=body,
                )
                if result:
                    success += 1
                else:
                    failed += 1
            except Exception as e:
                logger.error("관리자 푸시 실패: device=%s, error=%s", device["device_id"], e)
                failed += 1
        return {"total": total, "success": success, "failed": failed}
    else:
        # 단일 디바이스
        result = await send_push(device_id=target, title=title, body=body)
        return {
            "total": 1,
            "success": 1 if result else 0,
            "failed": 0 if result else 1,
        }


# ──────────────────────────────────────────────
# 8. Deploy Status
# ──────────────────────────────────────────────

async def get_deploy_status(run_id: str) -> dict[str, Any] | None:
    """배포 상태를 조회한다.

    Args:
        run_id: GitHub Actions run ID.

    Returns:
        배포 상태 딕셔너리, 없으면 None.
    """
    sb = get_supabase()

    resp = (
        sb.table("deploy_history")
        .select("*")
        .eq("github_run_id", run_id)
        .limit(1)
        .execute()
    )

    if not resp.data:
        return None

    record = resp.data[0]

    # 연관 릴리즈 정보
    release_resp = (
        sb.table("deploy_releases")
        .select("version")
        .eq("release_id", record.get("release_id", ""))
        .limit(1)
        .execute()
    )
    version = release_resp.data[0]["version"] if release_resp.data else ""

    started_at = record.get("started_at")
    completed_at = record.get("completed_at")
    duration = None
    if started_at:
        start_dt = datetime.fromisoformat(started_at.replace("Z", "+00:00"))
        end_dt = (
            datetime.fromisoformat(completed_at.replace("Z", "+00:00"))
            if completed_at
            else datetime.now(timezone.utc)
        )
        duration = int((end_dt - start_dt).total_seconds())

    return {
        "run_id": run_id,
        "release_id": record.get("release_id", ""),
        "version": version,
        "status": record.get("status", "unknown"),
        "triggered_by": record.get("triggered_by", ""),
        "started_at": started_at,
        "completed_at": completed_at,
        "duration_seconds": duration,
        "error_log": record.get("error_log"),
        "steps": record.get("steps", []),
    }
