"""Analytics service — event storage and tracking.

Uses Supabase as primary data store with in-memory fallback for resilience.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

# In-memory event store (fallback)
_events: list[dict] = []


def _get_sb():
    """Lazy-load Supabase client to avoid import errors when not configured."""
    try:
        from services.supabase_client import get_supabase
        return get_supabase()
    except Exception as e:
        logger.warning("Supabase client unavailable: %s", e)
        return None


class AnalyticsService:
    """Handles event tracking and storage.

    Uses Supabase as primary store. Falls back to in-memory list
    if Supabase is unavailable or queries fail.
    """

    async def store_events(self, device_id: str, events: list[dict]) -> int:
        """Store a batch of events from a device.

        Args:
            device_id: The device identifier.
            events: List of event dicts with name, properties, timestamp.

        Returns:
            Number of events successfully stored.
        """
        now = datetime.now(timezone.utc).isoformat()
        rows = [
            {
                "device_id": device_id,
                "name": event.get("name", "unknown"),
                "properties": event.get("properties", {}),
                "timestamp": event.get("timestamp", now),
                "received_at": now,
            }
            for event in events
        ]

        sb = _get_sb()
        if sb is not None:
            try:
                sb.table("events").insert(rows).execute()
                logger.info(
                    "Stored %d events for device %s in Supabase", len(rows), device_id
                )
                return len(rows)
            except Exception as e:
                logger.warning(
                    "Supabase store_events failed, falling back to mock: %s", e
                )

        # Fallback to in-memory
        _events.extend(rows)
        logger.info(
            "Stored %d events for device %s in memory (total: %d)",
            len(rows),
            device_id,
            len(_events),
        )
        return len(rows)

    def get_event_count(self) -> int:
        """Return total number of stored events (for health check).

        Returns:
            Total event count from Supabase or in-memory store.
        """
        sb = _get_sb()
        if sb is not None:
            try:
                resp = (
                    sb.table("events")
                    .select("id", count="exact")
                    .execute()
                )
                return resp.count or 0
            except Exception as e:
                logger.warning(
                    "Supabase get_event_count failed, falling back to mock: %s", e
                )

        return len(_events)

    async def get_events_by_device(
        self, device_id: str, limit: int = 100
    ) -> list[dict]:
        """Return events for a specific device.

        Args:
            device_id: The device identifier.
            limit: Maximum number of events to return.

        Returns:
            List of event dicts ordered by timestamp descending.
        """
        sb = _get_sb()
        if sb is not None:
            try:
                resp = (
                    sb.table("events")
                    .select("*")
                    .eq("device_id", device_id)
                    .order("timestamp", desc=True)
                    .limit(limit)
                    .execute()
                )
                return resp.data
            except Exception as e:
                logger.warning(
                    "Supabase get_events_by_device failed, falling back to mock: %s", e
                )

        # Fallback
        return [e for e in _events if e["device_id"] == device_id][:limit]

    async def track_event(self, event: dict) -> bool:
        """Track a single analytics event.

        Args:
            event: Event dict with name, properties, timestamp.

        Returns:
            True if the event was tracked successfully.
        """
        sb = _get_sb()
        if sb is not None:
            try:
                sb.table("events").insert(event).execute()
                return True
            except Exception as e:
                logger.warning(
                    "Supabase track_event failed, falling back to mock: %s", e
                )

        _events.append(event)
        return True

    async def track_events_batch(self, events: list[dict]) -> int:
        """Track multiple events. Returns count of successfully tracked events.

        Args:
            events: List of event dicts.

        Returns:
            Number of events successfully tracked.
        """
        sb = _get_sb()
        if sb is not None:
            try:
                sb.table("events").insert(events).execute()
                return len(events)
            except Exception as e:
                logger.warning(
                    "Supabase track_events_batch failed, falling back to mock: %s", e
                )

        _events.extend(events)
        return len(events)

    async def get_user_stats(self, user_id: str) -> dict:
        """Get aggregated stats for a specific user/device.

        Args:
            user_id: The device/user identifier.

        Returns:
            Dict with total_sessions, total_events, briefings_viewed,
            feed_interactions, and last_active.
        """
        sb = _get_sb()
        if sb is not None:
            try:
                resp = (
                    sb.table("events")
                    .select("*")
                    .eq("device_id", user_id)
                    .execute()
                )
                user_events = resp.data or []
                return self._aggregate_stats(user_events)
            except Exception as e:
                logger.warning(
                    "Supabase get_user_stats failed, falling back to mock: %s", e
                )

        # Fallback
        user_events = [e for e in _events if e.get("device_id") == user_id]
        return self._aggregate_stats(user_events)

    @staticmethod
    def _aggregate_stats(user_events: list[dict]) -> dict:
        """Aggregate event list into user stats summary.

        Args:
            user_events: List of event dicts for a single user.

        Returns:
            Aggregated stats dict.
        """
        return {
            "total_sessions": len(
                {
                    e.get("properties", {}).get("session_id")
                    for e in user_events
                    if e.get("properties", {}).get("session_id")
                }
            ),
            "total_events": len(user_events),
            "briefings_viewed": len(
                [e for e in user_events if e.get("name") == "briefing_viewed"]
            ),
            "feed_interactions": len(
                [e for e in user_events if e.get("name", "").startswith("feed_")]
            ),
            "last_active": max(
                (e.get("timestamp", "") for e in user_events), default=None
            ),
        }


analytics_service = AnalyticsService()
