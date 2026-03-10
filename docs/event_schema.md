# Portfiq Event Tracking Schema

> Version: 2.0.0
> Last updated: 2026-03-10

All client-side events are sent to `POST /api/v1/analytics/events` with the following base structure:

```json
{
  "event_name": "string",
  "user_id": "string",
  "timestamp": "ISO 8601",
  "properties": {
    "session_id": "string (auto-injected)"
  }
}
```

**Note:** `session_id` is automatically injected into all event properties by EventTracker.

---

## Session Events

### session_started

**Trigger:** App comes to foreground or is opened fresh.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| session_id | string | yes | Unique session identifier (auto-generated) |

```json
{
  "event_name": "session_started",
  "properties": {
    "session_id": "sess_abc123"
  }
}
```

### session_ended

**Trigger:** App goes to background or is closed.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| session_id | string | yes | Matching session identifier from session_started |
| duration_seconds | int | yes | Total session duration |
| screens_viewed | int | yes | Number of screen view events fired |
| events_count | int | yes | Total events fired during this session |

```json
{
  "event_name": "session_ended",
  "properties": {
    "session_id": "sess_abc123",
    "duration_seconds": 900,
    "screens_viewed": 5,
    "events_count": 23
  }
}
```

---

## Onboarding Events

### onboarding_started

**Trigger:** User opens the app for the first time and lands on the onboarding screen.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| source | string | yes | How the user arrived (e.g., "organic", "referral", "ad_campaign") |
| device_os | string | yes | "ios" or "android" |
| app_version | string | yes | App version string |

```json
{
  "event_name": "onboarding_started",
  "properties": {
    "source": "organic",
    "device_os": "ios",
    "app_version": "1.0.0"
  }
}
```

### etf_search_used

**Trigger:** User types a search query in the ETF search field (onboarding or my_etf).

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| query | string | yes | The search query text |
| source | string | no | "onboarding" or "my_etf" |

```json
{
  "event_name": "etf_search_used",
  "properties": {
    "query": "SPY",
    "source": "onboarding"
  }
}
```

### etf_chip_selected

**Trigger:** User taps an ETF chip during onboarding.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| ticker | string | yes | The ETF ticker tapped |
| source | string | yes | "popular_chip" or "search_result" |

```json
{
  "event_name": "etf_chip_selected",
  "properties": {
    "ticker": "QQQ",
    "source": "popular_chip"
  }
}
```

### etf_registered

**Trigger:** User selects and confirms ETFs during onboarding or from settings.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| tickers | string[] | yes | List of ETF tickers registered |
| count | int | yes | Number of ETFs registered |
| context | string | yes | "onboarding" or "settings" |

```json
{
  "event_name": "etf_registered",
  "properties": {
    "tickers": ["SPY", "QQQ", "ARKK"],
    "count": 3,
    "context": "onboarding"
  }
}
```

### push_permission_requested

**Trigger:** User taps the "알림 받기" button to request push permission.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| step | string | yes | Context where requested (e.g., "onboarding") |

```json
{
  "event_name": "push_permission_requested",
  "properties": {
    "step": "onboarding"
  }
}
```

### push_permission_granted

**Trigger:** User grants push notification permission.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| context | string | yes | "onboarding" or "settings" or "in_app_prompt" |

```json
{
  "event_name": "push_permission_granted",
  "properties": {
    "context": "onboarding"
  }
}
```

### push_permission_denied

**Trigger:** User denies push notification permission.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| context | string | yes | "onboarding" or "settings" or "in_app_prompt" |

```json
{
  "event_name": "push_permission_denied",
  "properties": {
    "context": "onboarding"
  }
}
```

### onboarding_completed

**Trigger:** User finishes the entire onboarding flow and enters the main app.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| etf_count | int | yes | Number of ETFs registered |
| duration_seconds | int | yes | Total time spent in onboarding |
| push_enabled | bool | yes | Whether push notifications were granted |

```json
{
  "event_name": "onboarding_completed",
  "properties": {
    "etf_count": 3,
    "duration_seconds": 300,
    "push_enabled": true
  }
}
```

---

## Navigation Events

### screen_viewed

**Trigger:** User navigates to any screen in the app (auto-tracked by ScreenObserver + manual calls).

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| screen_name | string | yes | Screen identifier (e.g., "feed", "briefing_detail", "etf_detail", "calendar", "settings") |
| previous_screen | string | no | Previous screen name (auto-populated by ScreenObserver) |
| param_* | string | no | Route parameters (auto-extracted by ScreenObserver, prefixed with `param_`) |

```json
{
  "event_name": "screen_viewed",
  "properties": {
    "screen_name": "etf_detail",
    "previous_screen": "feed",
    "param_ticker": "SPY"
  }
}
```

### tab_switch

**Trigger:** User switches between bottom navigation tabs.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| from | string | yes | Tab name being left |
| to | string | yes | Tab name being navigated to |

```json
{
  "event_name": "tab_switch",
  "properties": {
    "from": "Home",
    "to": "My ETF"
  }
}
```

---

## Feed Events

### feed_card_tapped

**Trigger:** User taps on a news card in the feed.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| card_id | string | yes | Unique identifier of the feed card |
| card_type | string | yes | "news", "impact_alert", "market_move" |
| position | int | yes | Position of the card in the feed (0-indexed) |
| related_etfs | string[] | yes | ETF tickers related to this card |
| impact_score | float | no | Impact score if available |

```json
{
  "event_name": "feed_card_tapped",
  "properties": {
    "card_id": "card_xyz789",
    "card_type": "impact_alert",
    "position": 2,
    "related_etfs": ["QQQ", "ARKK"],
    "impact_score": 0.85
  }
}
```

### news_card_viewed

**Trigger:** News card enters the viewport as user scrolls the feed.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| news_id | string | yes | Unique identifier of the news item |
| position | int | yes | Position of the card in the feed (0-indexed) |

```json
{
  "event_name": "news_card_viewed",
  "properties": {
    "news_id": "news_abc123",
    "position": 2
  }
}
```

### feed_scrolled_depth

**Trigger:** User scrolls to a new maximum index in the feed.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| max_index | int | yes | Maximum card index reached |
| total_items | int | yes | Total number of items in the feed |

```json
{
  "event_name": "feed_scrolled_depth",
  "properties": {
    "max_index": 8,
    "total_items": 15
  }
}
```

### feed_refreshed

**Trigger:** User pulls to refresh the feed.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| source | string | yes | "pull_to_refresh" |

```json
{
  "event_name": "feed_refreshed",
  "properties": {
    "source": "pull_to_refresh"
  }
}
```

### news_card_tap

**Trigger:** User taps a news card to open the detail bottom sheet.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| news_id | string | yes | News item identifier |
| sentiment | string | yes | "positive", "negative", or "neutral" |

```json
{
  "event_name": "news_card_tap",
  "properties": {
    "news_id": "news_abc123",
    "sentiment": "positive"
  }
}
```

### news_source_tap

**Trigger:** User taps to view the original news source.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| news_id | string | yes | News item identifier |
| source | string | yes | News source name |

```json
{
  "event_name": "news_source_tap",
  "properties": {
    "news_id": "news_abc123",
    "source": "Reuters"
  }
}
```

---

## Briefing Events

### briefing_card_tap

**Trigger:** User taps the briefing card in the feed to open detail.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| type | string | yes | "morning" or "night" |

```json
{
  "event_name": "briefing_card_tap",
  "properties": {
    "type": "morning"
  }
}
```

### briefing_viewed

**Trigger:** User opens and views the briefing detail screen.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| type | string | yes | "morning" or "night" |

```json
{
  "event_name": "briefing_viewed",
  "properties": {
    "type": "morning"
  }
}
```

### briefing_share_tap

**Trigger:** User taps the share button on a briefing.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| type | string | yes | "morning" or "night" |
| source | string | yes | "detail_screen" or "feed_card" |

```json
{
  "event_name": "briefing_share_tap",
  "properties": {
    "type": "morning",
    "source": "detail_screen"
  }
}
```

### briefing_shared

**Trigger:** Briefing was successfully shared.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| type | string | yes | "morning" or "night" |
| method | string | yes | Share method (e.g., "image_share") |
| source | string | yes | "detail_screen" or "feed_card" |

```json
{
  "event_name": "briefing_shared",
  "properties": {
    "type": "morning",
    "method": "image_share",
    "source": "detail_screen"
  }
}
```

---

## ETF Detail Events

### etf_detail_viewed

**Trigger:** User opens an ETF detail screen.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| ticker | string | yes | ETF ticker symbol |

```json
{
  "event_name": "etf_detail_viewed",
  "properties": {
    "ticker": "QQQ"
  }
}
```

### etf_holdings_expanded

**Trigger:** ETF holdings data loads and is displayed on the detail screen.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| ticker | string | yes | ETF ticker symbol |
| holdings_count | int | yes | Number of holdings loaded |

```json
{
  "event_name": "etf_holdings_expanded",
  "properties": {
    "ticker": "QQQ",
    "holdings_count": 10
  }
}
```

### holding_tap

**Trigger:** User taps a holding within an ETF to view company ETFs.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| ticker | string | yes | Holding ticker symbol |

```json
{
  "event_name": "holding_tap",
  "properties": {
    "ticker": "AAPL"
  }
}
```

---

## ETF Management Events

### etf_added

**Trigger:** User adds an ETF to their portfolio.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| ticker | string | yes | ETF ticker symbol |
| source | string | yes | "settings", "my_etf", or "onboarding" |

```json
{
  "event_name": "etf_added",
  "properties": {
    "ticker": "QQQ",
    "source": "my_etf"
  }
}
```

### etf_removed

**Trigger:** User removes an ETF from their portfolio.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| ticker | string | yes | ETF ticker symbol |
| source | string | yes | "settings" or "etf_detail" |

```json
{
  "event_name": "etf_removed",
  "properties": {
    "ticker": "QQQ",
    "source": "settings"
  }
}
```

---

## Settings Events

### notification_time_changed

**Trigger:** User toggles a notification setting (morning/night).

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| type | string | yes | "morning" or "night" |
| enabled | bool | yes | Whether the notification is now enabled |

```json
{
  "event_name": "notification_time_changed",
  "properties": {
    "type": "morning",
    "enabled": false
  }
}
```

### notification_disabled

**Trigger:** User disables a notification type.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| type | string | yes | "morning", "night", or "urgent_news" |

```json
{
  "event_name": "notification_disabled",
  "properties": {
    "type": "morning"
  }
}
```

---

## Permission Events

### push_permission_granted

**Trigger:** User grants push notification permission.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| context | string | yes | "onboarding" or "settings" or "in_app_prompt" |
| device_os | string | no | "ios" or "android" |

```json
{
  "event_name": "push_permission_granted",
  "properties": {
    "context": "onboarding"
  }
}
```

### push_permission_denied

**Trigger:** User denies push notification permission.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| context | string | yes | "onboarding" or "settings" or "in_app_prompt" |

```json
{
  "event_name": "push_permission_denied",
  "properties": {
    "context": "onboarding"
  }
}
```

---

## Legacy Events (kept for backward compatibility)

These events existed before v2.0.0 and are still fired alongside their canonical replacements:

| Legacy Event | Canonical Replacement | Notes |
|-------------|----------------------|-------|
| `feed_pull_refresh` | `feed_refreshed` | Both fired on pull-to-refresh |
| `etf_remove` | `etf_removed` | Both fired on ETF removal |
| `etf_add` | `etf_added` | Both fired on ETF addition |
| `etf_search` | `etf_search_used` | Both fired on search |
| `remove_etf` | `etf_removed` | Both fired on detail screen removal |
| `screen_view` | `screen_viewed` | Both naming conventions in use |
| `notification_toggle` | `notification_time_changed` | Both fired on toggle |
| `session_start` | `session_started` | Name aligned to past tense |
| `session_end` | `session_ended` | Name aligned to past tense |
