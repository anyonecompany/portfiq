"""Briefing router — AI-generated ETF briefings (morning & night)."""

from fastapi import APIRouter, Query

from services.briefing_service import briefing_service

router = APIRouter()


@router.get("/morning")
async def get_morning_briefing(
    device_id: str = Query(..., description="Device identifier"),
) -> dict:
    """Get today's morning briefing for the device's registered ETFs."""
    briefing = await briefing_service.get_morning_briefing(device_id)
    return briefing.model_dump()


@router.get("/night")
async def get_night_briefing(
    device_id: str = Query(..., description="Device identifier"),
) -> dict:
    """Get tonight's checkpoint briefing."""
    briefing = await briefing_service.get_night_briefing(device_id)
    return briefing.model_dump()


@router.post("/generate")
async def generate_briefing(
    device_id: str = Query(..., description="Device identifier"),
) -> dict:
    """Manually trigger briefing generation (stub for Claude API integration)."""
    briefing = await briefing_service.generate_briefing(device_id)
    return {"status": "generated", "briefing": briefing.model_dump()}
