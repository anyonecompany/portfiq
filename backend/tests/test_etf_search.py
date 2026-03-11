"""ETF search endpoint tests — minimum 1 test per API route."""


def test_etf_search_returns_results(client):
    """GET /api/v1/etf/search?q=SPY returns 200."""
    resp = client.get("/api/v1/etf/search", params={"q": "SPY"})
    assert resp.status_code == 200
    data = resp.json()
    assert "results" in data
    assert "total" in data


def test_etf_search_requires_query(client):
    """GET /api/v1/etf/search without q returns 422."""
    resp = client.get("/api/v1/etf/search")
    assert resp.status_code == 422


def test_etf_popular(client):
    """GET /api/v1/etf/popular returns 200."""
    resp = client.get("/api/v1/etf/popular")
    assert resp.status_code == 200
