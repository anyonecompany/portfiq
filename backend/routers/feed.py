"""Feed router — personalized ETF news feed.

Supabase 시그널 파이프라인 데이터를 우선 조회하고,
데이터 없을 시 기존 news_service(메모리 캐시)로 fallback한다.
"""

import logging

from fastapi import APIRouter, Query

from services.news_service import news_service
from services.etf_service import etf_service
from services.signal_feed_service import get_signal_feed, get_latest_signal_feed

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("")
async def get_feed(
    device_id: str = Query(..., description="Device identifier"),
    offset: int = Query(0, ge=0, description="Number of items to skip"),
    limit: int = Query(20, ge=1, le=100, description="Number of items to return"),
) -> dict:
    """Get personalized feed for a device based on their registered ETFs.

    Supabase 시그널 피드 우선 → 없으면 기존 메모리 캐시 fallback.
    """
    # 1차: Supabase 시그널 피드 조회
    signal_items = await get_signal_feed(device_id, offset, limit)
    if signal_items:
        return {
            "items": [item.model_dump() for item in signal_items],
            "total": len(signal_items),
            "offset": offset,
            "limit": limit,
            "has_more": len(signal_items) >= limit,
        }

    # Fallback: 기존 메모리 캐시 파이프라인
    logger.info("시그널 피드 없음, 기존 파이프라인 fallback (device_id=%s)", device_id)
    tickers = await etf_service.get_registered(device_id)
    if not tickers:
        items = await news_service.get_all_news()
    else:
        items = await news_service.get_news_for_etfs(tickers)
    paged_items = items[offset:offset + limit]
    return {
        "items": [item.model_dump() for item in paged_items],
        "total": len(items),
        "offset": offset,
        "limit": limit,
        "has_more": offset + limit < len(items),
    }


@router.get("/latest")
async def get_latest_feed(
    offset: int = Query(0, ge=0, description="Number of items to skip"),
    limit: int = Query(20, ge=1, le=100, description="Number of items to return"),
) -> dict:
    """Get latest news feed with pagination (all news, no personalization).

    Supabase 번역+분류 완료 기사 우선 → 없으면 기존 fallback.
    """
    # 1차: Supabase 최신 시그널 피드
    signal_items, signal_total = await get_latest_signal_feed(offset, limit)
    if signal_items:
        return {
            "items": [item.model_dump() for item in signal_items],
            "total": signal_total,
            "offset": offset,
            "limit": limit,
            "has_more": offset + limit < signal_total,
        }

    # Fallback: 기존 메모리 캐시
    logger.info("최신 시그널 피드 없음, 기존 파이프라인 fallback")
    items, total = await news_service.get_all_news_paginated(offset=offset, limit=limit)
    return {
        "items": [item.model_dump() for item in items],
        "total": total,
        "offset": offset,
        "limit": limit,
        "has_more": offset + limit < total,
    }


@router.post("/refresh")
async def refresh_feed() -> dict:
    """Clear all caches and regenerate news + briefings.

    Clears: TTL cache, news cache, briefing cache.
    Then triggers fresh news collection + translation + briefing generation.
    """
    from services.cache import clear_cache
    from services.briefing_service import briefing_service, _last_morning_briefing, _last_night_briefing
    import services.briefing_service as bs

    # 1. Clear all caches
    cleared = clear_cache()
    logger.info("TTL 캐시 클리어: %d entries", cleared)

    # 2. Clear news in-memory cache
    from services.news_service import _news_cache
    import services.news_service as ns
    old_count = len(ns._news_cache)
    ns._news_cache = []
    logger.info("뉴스 캐시 클리어: %d articles", old_count)

    # 3. Clear stale briefing cache
    bs._last_morning_briefing = None
    bs._last_night_briefing = None
    logger.info("브리핑 stale 캐시 클리어")

    # 4. Trigger fresh news collection + translation
    from services.news_service import fetch_and_store_news
    news_count = await fetch_and_store_news()
    logger.info("뉴스 재수집 완료: %d articles", news_count)

    # 5. Trigger briefing regeneration (both morning and night)
    morning = await briefing_service.generate_morning_briefing_background("system")
    night = await briefing_service.generate_night_briefing_background("system")

    return {
        "cache_cleared": cleared,
        "news_cleared": old_count,
        "news_collected": news_count,
        "morning_briefing": "generated" if not morning.is_mock else "mock_fallback",
        "night_briefing": "generated" if not night.is_mock else "mock_fallback",
    }
