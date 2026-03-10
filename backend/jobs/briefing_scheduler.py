"""브리핑 스케줄러 — APScheduler CronTrigger 기반.

등록된 모든 디바이스에 대해 브리핑을 생성하고 FCM 푸시를 전송한다.
추가로 일간 메트릭 집계, 퍼널 코호트 집계, 주말 브리핑 Job도 관리한다.
"""

import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

from config import settings

logger = logging.getLogger(__name__)

scheduler: AsyncIOScheduler | None = None


def start_scheduler() -> AsyncIOScheduler:
    """스케줄러 시작. 모든 Job 등록."""
    global scheduler
    scheduler = AsyncIOScheduler()

    # 1. 뉴스 수집: 3분마다 (실시간 금융 뉴스 서비스)
    scheduler.add_job(
        _run_news_collection,
        IntervalTrigger(minutes=3),
        id="news_collector",
        name="뉴스 수집",
        replace_existing=True,
    )

    # 2. 아침 브리핑: 매일 설정된 시간 KST (UTC로 변환: KST - 9)
    morning_utc_hour = (settings.BRIEFING_MORNING_HOUR - 9) % 24
    scheduler.add_job(
        _run_morning_briefing,
        CronTrigger(hour=morning_utc_hour, minute=settings.BRIEFING_MORNING_MINUTE),
        id="morning_briefing",
        name="아침 브리핑 생성",
        replace_existing=True,
    )

    # 3. 밤 체크포인트: 매일 설정된 시간 KST (UTC로 변환: KST - 9)
    night_utc_hour = (settings.BRIEFING_NIGHT_HOUR - 9) % 24
    scheduler.add_job(
        _run_night_briefing,
        CronTrigger(hour=night_utc_hour, minute=0),
        id="night_briefing",
        name="밤 체크포인트 생성",
        replace_existing=True,
    )

    # 4. 서버 시작 직후 뉴스 수집 1회 즉시 실행 (5초 후)
    from datetime import datetime, timedelta
    scheduler.add_job(
        _run_news_collection,
        "date",
        run_date=datetime.now() + timedelta(seconds=5),
        id="news_collector_initial",
        name="초기 뉴스 수집",
    )

    # 5. 일간 메트릭 집계: 01:00 KST = 16:00 UTC
    scheduler.add_job(
        _run_daily_aggregation,
        CronTrigger(hour=16, minute=0),
        id="daily_aggregation",
        name="일간 메트릭 집계",
        replace_existing=True,
    )

    # 6. 퍼널 코호트 집계: 01:30 KST = 16:30 UTC
    scheduler.add_job(
        _run_funnel_aggregation,
        CronTrigger(hour=16, minute=30),
        id="funnel_aggregation",
        name="퍼널 코호트 집계",
        replace_existing=True,
    )

    # 7. 주말 브리핑 — 토요일 08:35 KST (23:35 UTC 금요일)
    scheduler.add_job(
        _run_weekend_weekly_summary,
        CronTrigger(
            day_of_week="fri", hour=23, minute=35,  # 토요일 08:35 KST
            timezone="Asia/Seoul",
        ),
        id="weekend_weekly_summary",
        name="주간 ETF 요약 브리핑 (토요일)",
        replace_existing=True,
    )

    # 8. 주말 브리핑 — 일요일 22:00 KST (13:00 UTC 일요일)
    scheduler.add_job(
        _run_weekend_monday_checklist,
        CronTrigger(
            day_of_week="sun", hour=13, minute=0,  # 일요일 22:00 KST
            timezone="Asia/Seoul",
        ),
        id="weekend_monday_checklist",
        name="다음주 월요일 체크리스트 브리핑 (일요일)",
        replace_existing=True,
    )

    # 9. 보유종목 스냅샷: 매주 월요일 01:00 KST (일요일 16:00 UTC)
    scheduler.add_job(
        _run_holdings_snapshot,
        CronTrigger(day_of_week="sun", hour=16, minute=0),
        id="holdings_snapshot",
        name="주간 보유종목 스냅샷",
        replace_existing=True,
    )

    scheduler.start()
    logger.info(
        "스케줄러 시작: 뉴스(3분), 아침(%02d:%02d KST), 밤(%02d:00 KST), "
        "집계(01:00 KST), 퍼널(01:30 KST), 주말(토08:35/일22:00 KST), 스냅샷(월01:00 KST)",
        settings.BRIEFING_MORNING_HOUR,
        settings.BRIEFING_MORNING_MINUTE,
        settings.BRIEFING_NIGHT_HOUR,
    )
    return scheduler


def stop_scheduler() -> None:
    """스케줄러 중지."""
    global scheduler
    if scheduler and scheduler.running:
        scheduler.shutdown(wait=False)
        logger.info("스케줄러 중지")


async def _run_news_collection() -> None:
    """뉴스 수집 Job 실행."""
    from jobs.news_collector import collect_news
    await collect_news()


async def _generate_and_push_for_all_devices(briefing_type: str) -> None:
    """모든 등록 디바이스에 대해 브리핑 생성 + 푸시 전송.

    각 디바이스별로 독립 처리하여 한 디바이스의 실패가 다른 디바이스에 영향을 주지 않는다.

    Args:
        briefing_type: "morning" 또는 "night".
    """
    from services.briefing_service import briefing_service
    from services.push_service import send_briefing_push, _get_all_device_tokens

    type_label = "아침 브리핑" if briefing_type == "morning" else "밤 체크포인트"
    devices = _get_all_device_tokens()

    if not devices:
        logger.info("%s: 등록된 디바이스 없음, 스킵", type_label)
        return

    logger.info("%s 생성 시작: %d개 디바이스 대상", type_label, len(devices))

    success_count = 0
    fail_count = 0

    for device_info in devices:
        device_id = device_info["device_id"]
        try:
            # 디바이스별 브리핑 생성
            if briefing_type == "morning":
                briefing = await briefing_service.get_morning_briefing(device_id)
            else:
                briefing = await briefing_service.get_night_briefing(device_id)

            # 푸시 전송
            emoji = "\U0001f305" if briefing_type == "morning" else "\U0001f319"
            push_body = f"{emoji} {briefing.summary[:80]}" if briefing.summary else ""

            sent = await send_briefing_push(
                device_id=device_id,
                briefing_type=briefing_type,
                title=briefing.title,
                body=push_body,
            )

            if sent:
                success_count += 1
                logger.debug("%s 전송 성공: device=%s", type_label, device_id)
            else:
                fail_count += 1
                logger.warning("%s 푸시 실패: device=%s", type_label, device_id)

        except Exception as e:
            fail_count += 1
            logger.error(
                "%s 처리 실패: device=%s, error=%s",
                type_label, device_id, e,
            )

    logger.info(
        "%s 완료: 성공=%d, 실패=%d, 전체=%d",
        type_label, success_count, fail_count, len(devices),
    )


async def _run_morning_briefing() -> None:
    """아침 브리핑 생성 Job 실행."""
    logger.info("아침 브리핑 생성 시작")
    try:
        await _generate_and_push_for_all_devices("morning")
    except Exception as e:
        logger.error("아침 브리핑 생성 실패: %s", e)


async def _run_night_briefing() -> None:
    """밤 체크포인트 생성 Job 실행."""
    logger.info("밤 체크포인트 생성 시작")
    try:
        await _generate_and_push_for_all_devices("night")
    except Exception as e:
        logger.error("밤 체크포인트 생성 실패: %s", e)


async def _run_daily_aggregation() -> None:
    """일간 메트릭 집계 Job 실행."""
    logger.info("일간 메트릭 집계 시작")
    try:
        from jobs.aggregation import aggregate_daily_metrics
        await aggregate_daily_metrics()
    except Exception as e:
        logger.error("일간 메트릭 집계 실패: %s", e)


async def _run_funnel_aggregation() -> None:
    """퍼널 코호트 집계 Job 실행."""
    logger.info("퍼널 코호트 집계 시작")
    try:
        from jobs.funnel_aggregation import aggregate_funnel_cohort
        await aggregate_funnel_cohort()
    except Exception as e:
        logger.error("퍼널 코호트 집계 실패: %s", e)


async def _run_weekend_weekly_summary() -> None:
    """주간 ETF 요약 브리핑 생성 (토요일 08:35 KST).

    모든 등록 디바이스에 주간 ETF 성과 요약 브리핑을 생성·전송한다.
    """
    logger.info("주간 ETF 요약 브리핑 생성 시작 (토요일)")
    try:
        await _generate_and_push_for_all_devices("morning")
    except Exception as e:
        logger.error("주간 ETF 요약 브리핑 실패: %s", e)


async def _run_weekend_monday_checklist() -> None:
    """다음주 월요일 체크리스트 브리핑 생성 (일요일 22:00 KST).

    모든 등록 디바이스에 다음주 월요일 대비 체크리스트 브리핑을 생성·전송한다.
    """
    logger.info("월요일 체크리스트 브리핑 생성 시작 (일요일)")
    try:
        await _generate_and_push_for_all_devices("night")
    except Exception as e:
        logger.error("월요일 체크리스트 브리핑 실패: %s", e)


async def _run_holdings_snapshot() -> None:
    """주간 보유종목 스냅샷 저장 (월요일 01:00 KST).

    etf_master.json의 모든 ETF 보유종목을 Supabase holdings_snapshots 테이블에 저장한다.
    이 스냅샷은 get_holdings_changes에서 주간 변동 비교에 사용된다.
    """
    logger.info("주간 보유종목 스냅샷 시작")
    try:
        import json
        from datetime import datetime, timezone
        from pathlib import Path
        from services.supabase_client import get_supabase

        sb = get_supabase()
        json_path = Path(__file__).resolve().parent.parent / "seeds" / "etf_master.json"

        if not json_path.exists():
            logger.warning("etf_master.json 없음, 스냅샷 스킵")
            return

        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)

        now = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        rows = []
        for etf in data:
            ticker = etf.get("ticker", "").upper()
            holdings = etf.get("top_holdings", [])
            if ticker and holdings:
                rows.append({
                    "ticker": ticker,
                    "holdings": holdings,
                    "snapshot_date": now,
                })

        if rows:
            # Upsert: 같은 날짜+티커 조합은 덮어쓰기
            sb.table("holdings_snapshots").upsert(
                rows, on_conflict="ticker,snapshot_date"
            ).execute()
            logger.info("보유종목 스냅샷 저장 완료: %d개 ETF", len(rows))
        else:
            logger.warning("저장할 보유종목 없음")

    except Exception as e:
        logger.error("보유종목 스냅샷 실패: %s", e)
