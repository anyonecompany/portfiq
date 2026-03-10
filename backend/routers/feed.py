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
        # No ETFs registered — return empty feed
        return {"items": [], "total": 0, "message": "No ETFs registered. Register ETFs first."}

    items = await news_service.get_news_for_etfs(tickers)
    return {
        "items": [item.model_dump() for item in items],
        "total": len(items),
    }


@router.get("/latest")
async def get_latest_feed() -> dict:
    """Get latest news feed (all news, no personalization)."""
    items = await news_service.get_all_news()
    return {
        "items": [item.model_dump() for item in items],
        "total": len(items),
    }
