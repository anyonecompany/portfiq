# Portfiq API Specification

> Version: 1.0.0
> Base URL: `https://api.portfiq.com/api/v1`

---

## Health Check

### GET /health

Check API availability.

**Response 200:**
```json
{
  "status": "ok",
  "version": "1.0.0"
}
```

---

## Feed

### GET /api/v1/feed/

Get personalized feed for a user based on their registered ETFs.

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| user_id | string | yes | - | User identifier |
| cursor | string | no | null | Pagination cursor from previous response |
| limit | int | no | 20 | Items per page (1-50) |

**Response 200:**
```json
{
  "items": [
    {
      "id": "card_xyz789",
      "title": "Fed signals rate pause, tech ETFs rally",
      "summary": "Federal Reserve Chair indicated...",
      "source": "Reuters",
      "published_at": "2026-03-10T08:00:00Z",
      "related_etfs": ["QQQ", "XLK"],
      "impact_score": 0.82,
      "image_url": "https://..."
    }
  ],
  "next_cursor": "eyJwIjoyMH0=",
  "has_more": true
}
```

### GET /api/v1/feed/trending

Get trending ETF news across all users.

**Response 200:**
```json
{
  "items": [
    {
      "id": "card_abc456",
      "title": "S&P 500 hits new all-time high",
      "summary": "...",
      "source": "Bloomberg",
      "published_at": "2026-03-10T06:00:00Z",
      "related_etfs": ["SPY", "VOO", "IVV"],
      "impact_score": 0.91,
      "image_url": null
    }
  ]
}
```

---

## Briefing

### GET /api/v1/briefing/today

Get today's AI-generated briefing for the user.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| user_id | string | yes | User identifier |

**Response 200:**
```json
{
  "briefing_id": "brief_20260310_abc",
  "date": "2026-03-10",
  "sections": [
    {
      "title": "Market Overview",
      "content": "The S&P 500 closed up 0.8% yesterday...",
      "etf_tickers": ["SPY", "QQQ"],
      "impact_score": 0.75
    },
    {
      "title": "Your Portfolio Impact",
      "content": "ARKK may see pressure due to...",
      "etf_tickers": ["ARKK"],
      "impact_score": 0.85
    }
  ],
  "generated_at": "2026-03-10T06:00:00Z"
}
```

### GET /api/v1/briefing/{briefing_id}

Get a specific briefing by ID.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| briefing_id | string | Briefing identifier |

**Response 200:** Same structure as briefing/today response.

**Response 404:**
```json
{
  "detail": "Briefing not found"
}
```

### GET /api/v1/briefing/history

Get past briefings for a user.

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| user_id | string | yes | - | User identifier |
| limit | int | no | 7 | Number of past briefings (1-30) |

**Response 200:**
```json
{
  "items": [
    {
      "briefing_id": "brief_20260310_abc",
      "date": "2026-03-10",
      "sections": [],
      "generated_at": "2026-03-10T06:00:00Z"
    }
  ],
  "total": 7
}
```

---

## ETF

### GET /api/v1/etf/search

Search ETFs by name, ticker, or category.

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| q | string | yes | - | Search query (min 1 char) |
| limit | int | no | 20 | Results per page (1-50) |

**Response 200:**
```json
{
  "results": [
    {
      "ticker": "SPY",
      "name": "SPDR S&P 500 ETF Trust",
      "category": "Large Cap Blend",
      "price": 523.45,
      "change_pct": 0.82
    }
  ],
  "total": 1
}
```

### GET /api/v1/etf/{ticker}

Get detailed information about a specific ETF.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| ticker | string | ETF ticker symbol |

**Response 200:**
```json
{
  "ticker": "SPY",
  "name": "SPDR S&P 500 ETF Trust",
  "category": "Large Cap Blend",
  "price": 523.45,
  "change_pct": 0.82,
  "market_cap": 502000000000,
  "expense_ratio": 0.0945,
  "holdings": [
    {"name": "Apple Inc", "ticker": "AAPL", "weight_pct": 7.2},
    {"name": "Microsoft Corp", "ticker": "MSFT", "weight_pct": 6.8}
  ],
  "related_news": [
    {
      "id": "card_abc",
      "title": "S&P 500 rally continues",
      "published_at": "2026-03-10T08:00:00Z"
    }
  ]
}
```

**Response 404:**
```json
{
  "detail": "ETF not found"
}
```

### POST /api/v1/etf/register

Register ETFs to a user's watchlist.

**Request Body:**
```json
{
  "user_id": "usr_abc123",
  "tickers": ["SPY", "QQQ", "ARKK"]
}
```

**Response 200:**
```json
{
  "registered": ["SPY", "QQQ", "ARKK"],
  "total": 3
}
```

**Response 422:** Validation error (empty tickers, exceeds max 20).

### GET /api/v1/etf/registered

Get user's registered ETFs.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| user_id | string | yes | User identifier |

**Response 200:**
```json
{
  "etfs": [
    {
      "ticker": "SPY",
      "name": "SPDR S&P 500 ETF Trust",
      "category": "Large Cap Blend",
      "price": 523.45,
      "change_pct": 0.82
    }
  ],
  "total": 3
}
```

### DELETE /api/v1/etf/register/{ticker}

Remove an ETF from user's watchlist.

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| ticker | string | ETF ticker to remove |

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| user_id | string | yes | User identifier |

**Response 200:**
```json
{
  "removed": "ARKK"
}
```

---

## Analytics

### POST /api/v1/analytics/events

Track a batch of analytics events from one device.

**Headers:**
```http
X-Device-ID: dev_abc123
```

**Request Body:**
```json
{
  "device_id": "dev_abc123",
  "events": [
    {
      "event_name": "session_started",
      "timestamp": "2026-03-10T09:00:00Z",
      "properties": {"session_id": "sess_abc"}
    },
    {
      "event_name": "screen_viewed",
      "timestamp": "2026-03-10T09:00:01Z",
      "properties": {"screen_name": "feed"}
    }
  ]
}
```

**Response 202:**
```json
{
  "status": "accepted",
  "count": 2,
  "accepted": 2
}
```

---

## Admin

### GET /api/v1/admin/dashboard

Get platform-wide dashboard KPIs (internal use).

### GET /api/v1/admin/users

List all users with activity summary (internal use).

**Response 200:**
```json
{
  "users": [],
  "total": 0
}
```

---

## Error Responses

All errors follow this format:

```json
{
  "detail": "Human-readable error message"
}
```

| Status Code | Meaning |
|-------------|---------|
| 400 | Bad request (invalid parameters) |
| 404 | Resource not found |
| 422 | Validation error (Pydantic) |
| 429 | Rate limited |
| 500 | Internal server error |
