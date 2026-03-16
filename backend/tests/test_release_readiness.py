"""Release-readiness smoke tests for the launch-critical paths."""


def test_device_registration_persists_metadata_shape(client):
    """Device registration accepts platform/app version payload."""
    resp = client.post(
        "/api/v1/etf/devices/register",
        json={
            "device_id": "smoke-device",
            "push_token": "push-token-123",
            "platform": "ios",
            "app_version": "1.0.0+1",
        },
    )
    assert resp.status_code == 200
    assert resp.json()["success"] is True


def test_device_preferences_support_fallback_storage(client):
    """Preference update should stay writable even if Supabase is unavailable."""
    update_resp = client.put(
        "/api/v1/devices/smoke-device/preferences",
        json={
            "morning_briefing": False,
            "night_checkpoint": True,
            "urgent_news": True,
        },
    )
    assert update_resp.status_code == 200
    update_data = update_resp.json()
    assert update_data["success"] is True
    assert update_data["morning_briefing"] is False
    assert update_data["urgent_news"] is True

    get_resp = client.get("/api/v1/devices/smoke-device/preferences")
    assert get_resp.status_code == 200
    get_data = get_resp.json()
    assert get_data["morning_briefing"] is False
    assert get_data["night_checkpoint"] is True
    assert get_data["urgent_news"] is True


def test_analytics_batch_accepts_canonical_payload(client):
    """Analytics ingestion accepts the current mobile payload contract."""
    resp = client.post(
        "/api/v1/analytics/events",
        headers={"X-Device-ID": "smoke-device"},
        json={
            "device_id": "smoke-device",
            "events": [
                {
                    "event_name": "session_started",
                    "timestamp": "2026-03-14T00:00:00Z",
                    "properties": {
                        "platform": "ios",
                        "app_version": "1.0.0+1",
                    },
                }
            ],
        },
    )
    assert resp.status_code == 202
    assert resp.json()["accepted"] == 1
