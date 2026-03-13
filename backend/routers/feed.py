"""Feed router — personalized ETF news feed."""

from fastapi import APIRouter, Query

from services.news_service import news_service
from services.etf_service import etf_service

router = APIRouter()


@router.get("")
async def get_feed(
    device_id: str = Query(..., description="Device identifier"),
) -> dict:
    """Get personalized feed for a device based on their registered ETFs.

    Returns news items filtered by the device's registered ETFs,
    sorted by impact relevance.
    """
    tickers = await etf_service.get_registered(device_id)
    if not tickers:
        # ETF 미등록 시 전체 뉴스 반환
        items = await news_service.get_all_news()
    else:
        items = await news_service.get_news_for_etfs(tickers)
    return {
        "items": [item.model_dump() for item in items],
        "total": len(items),
    }


@router.get("/latest")
async def get_latest_feed(
    offset: int = Query(0, ge=0, description="Number of items to skip"),
    limit: int = Query(20, ge=1, le=100, description="Number of items to return"),
) -> dict:
    """Get latest news feed with pagination (all news, no personalization).

    Supports browsing past news beyond the 24-hour window via offset/limit.
    """
    items, total = await news_service.get_all_news_paginated(offset=offset, limit=limit)
    return {
        "items": [item.model_dump() for item in items],
        "total": total,
        "offset": offset,
        "limit": limit,
        "has_more": offset + limit < total,
    }
