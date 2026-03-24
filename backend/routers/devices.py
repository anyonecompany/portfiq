"""Device preferences router — notification preference CRUD per device."""

import logging

from fastapi import APIRouter, Path

from models.schemas import NotificationPreferences

logger = logging.getLogger(__name__)

router = APIRouter()

# Default preferences for new devices
_DEFAULT_PREFS = NotificationPreferences()
_PREFERENCE_FALLBACKS: dict[str, dict[str, bool]] = {}


@router.get("/{device_id}/preferences")
async def get_preferences(
    device_id: str = Path(..., description="Device identifier"),
) -> dict:
    """Get notification preferences for a device.

    Returns defaults if the device has no stored preferences.

    Args:
        device_id: Target device ID.

    Returns:
        Current notification preferences.
    """
    try:
        from services.supabase_client import get_supabase

        sb = get_supabase()
        resp = (
            sb.table("devices")
            .select("morning_briefing, night_checkpoint, urgent_news")
            .eq("device_id", device_id)
            .execute()
        )
        rows: list[dict] = resp.data  # type: ignore[assignment]
        if rows:
            row = rows[0]
            return {
                "morning_briefing": row.get("morning_briefing", True)
                if row.get("morning_briefing") is not None
                else True,
                "night_checkpoint": row.get("night_checkpoint", True)
                if row.get("night_checkpoint") is not None
                else True,
                "urgent_news": row.get("urgent_news", False)
                if row.get("urgent_news") is not None
                else False,
            }
    except Exception as e:
        logger.warning("Supabase 기기 설정 조회 실패: %s", e)

    if device_id in _PREFERENCE_FALLBACKS:
        return _PREFERENCE_FALLBACKS[device_id]

    # Device not found or Supabase error — return defaults
    return _DEFAULT_PREFS.model_dump()


@router.put("/{device_id}/preferences")
async def update_preferences(
    prefs: NotificationPreferences,
    device_id: str = Path(..., description="Device identifier"),
) -> dict:
    """Update notification preferences for a device.

    Uses upsert so the device row is created if it doesn't exist yet.

    Args:
        prefs: New notification preference values.
        device_id: Target device ID.

    Returns:
        Updated preferences with success flag.
    """
    try:
        from services.supabase_client import get_supabase

        sb = get_supabase()
        sb.table("devices").upsert(
            {
                "device_id": device_id,
                "morning_briefing": prefs.morning_briefing,
                "night_checkpoint": prefs.night_checkpoint,
                "urgent_news": prefs.urgent_news,
            },
            on_conflict="device_id",
        ).execute()

        logger.info(
            "알림 설정 저장: device=%s, prefs=%s", device_id, prefs.model_dump()
        )
        return {"success": True, **prefs.model_dump()}

    except Exception as e:
        logger.warning(
            "Supabase 설정 저장 실패, 인메모리 fallback 사용: device=%s, error=%s",
            device_id,
            e,
        )
        _PREFERENCE_FALLBACKS[device_id] = prefs.model_dump()
        return {"success": True, **prefs.model_dump(), "is_fallback": True}
