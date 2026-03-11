"""Feed endpoint tests."""


def test_feed_requires_device_id(client):
    """GET /api/v1/feed without device_id returns 422."""
    resp = client.get("/api/v1/feed")
    assert resp.status_code == 422


def test_feed_empty_device(client):
    """GET /api/v1/feed with unknown device returns empty or valid response."""
    resp = client.get("/api/v1/feed", params={"device_id": "test-device-nonexistent"})
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
