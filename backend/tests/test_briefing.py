"""Briefing endpoint tests."""


def test_morning_briefing_requires_device_id(client):
    """GET /api/v1/briefing/morning without device_id returns 422."""
    resp = client.get("/api/v1/briefing/morning")
    assert resp.status_code == 422


def test_night_briefing_requires_device_id(client):
    """GET /api/v1/briefing/night without device_id returns 422."""
    resp = client.get("/api/v1/briefing/night")
    assert resp.status_code == 422
