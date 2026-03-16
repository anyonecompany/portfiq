"""Tests for personalized briefing generation."""


def test_morning_briefing_uses_registered_etfs(client):
    """Morning briefing should reflect the requesting device's ETF set."""
    register_a = client.post(
        "/api/v1/etf/register",
        json={"device_id": "briefing-device-a", "tickers": ["QQQ", "SCHD"]},
    )
    register_b = client.post(
        "/api/v1/etf/register",
        json={"device_id": "briefing-device-b", "tickers": ["TLT"]},
    )

    assert register_a.status_code == 200
    assert register_b.status_code == 200

    morning_a = client.get(
        "/api/v1/briefing/morning",
        params={"device_id": "briefing-device-a"},
    )
    morning_b = client.get(
        "/api/v1/briefing/morning",
        params={"device_id": "briefing-device-b"},
    )

    assert morning_a.status_code == 200
    assert morning_b.status_code == 200

    tickers_a = [item["ticker"] for item in morning_a.json()["etf_changes"]]
    tickers_b = [item["ticker"] for item in morning_b.json()["etf_changes"]]

    assert "QQQ" in tickers_a
    assert "SCHD" in tickers_a
    assert tickers_b == ["TLT"]
    assert tickers_a != tickers_b
