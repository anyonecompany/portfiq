# Portfiq Admin Dashboard — API Specification

> Version: 1.0.0
> Last updated: 2026-03-10
> Base URL: `https://api.portfiq.com/api/v1/admin`

---

## Table of Contents

1. [Authentication](#authentication)
2. [Dashboard KPI](#1-dashboard-kpi)
3. [Funnel Analysis](#2-funnel-analysis)
4. [Cohort Retention](#3-cohort-retention)
5. [Push Performance](#4-push-performance)
6. [User Statistics](#5-user-statistics)
7. [Event Explorer](#6-event-explorer)
8. [Deploy Approval](#7-deploy-approval)
9. [Deploy Execute](#8-deploy-execute)
10. [Deploy Status](#9-deploy-status)
11. [Admin Login](#10-admin-login)
12. [Frontend Folder Structure](#frontend-folder-structure)
13. [Database Schema](#database-schema)

---

## Authentication

### Mechanism

All admin endpoints require a JWT bearer token in the `Authorization` header.

```
Authorization: Bearer <jwt_token>
```

### JWT Claims

```json
{
  "sub": "admin_user_id",
  "email": "ceo@portfiq.com",
  "role": "ceo",
  "iat": 1741564800,
  "exp": 1741593600
}
```

### Roles & Permissions

| Role | Dashboard | Funnel | Retention | Push | Users | Events | Deploy |
|------|-----------|--------|-----------|------|-------|--------|--------|
| `ceo` | read | read | read | read | read | read | approve + execute |
| `cto` | read | read | read | read | read | read | approve + execute |
| `pm`  | read | read | read | read | read | read | -- |

### Token Lifecycle

| Property | Value |
|----------|-------|
| Algorithm | HS256 |
| Expiry | 8 hours |
| Refresh | Not supported (re-login required) |
| Secret | `ADMIN_JWT_SECRET` environment variable |

### Error: Unauthorized

All endpoints return this when token is missing or invalid:

```json
// 401
{
  "detail": "Not authenticated"
}
```

### Error: Forbidden

Returned when the user's role lacks permission:

```json
// 403
{
  "detail": "Insufficient permissions. Required role: ceo or cto"
}
```

---

## 10. Admin Login

### POST /api/v1/admin/auth/login

Authenticate an admin user and receive a JWT token.

**Required Role:** None (public endpoint)

**Request Body:**
```json
{
  "email": "ceo@portfiq.com",
  "password": "string"
}
```

**Response 200:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "bearer",
  "expires_in": 28800,
  "user": {
    "id": 1,
    "email": "ceo@portfiq.com",
    "role": "ceo"
  }
}
```

**Response 401:**
```json
{
  "detail": "Invalid email or password"
}
```

---

## 1. Dashboard KPI

### GET /api/v1/admin/dashboard

Returns key performance indicators with comparison to the previous day.

**Required Role:** `ceo`, `cto`, `pm`

**Query Parameters:** None

**Response 200:**
```json
{
  "date": "2026-03-10",
  "kpis": {
    "dau": {
      "value": 1234,
      "change_pct": 5.2,
      "direction": "up"
    },
    "d7_retention": {
      "value": 42.5,
      "change_pct": -1.3,
      "direction": "down"
    },
    "new_installs": {
      "value": 89,
      "change_pct": 12.0,
      "direction": "up"
    },
    "onboarding_conversion": {
      "value": 67.3,
      "change_pct": 0.0,
      "direction": "flat"
    },
    "briefings_generated": {
      "value": 2450,
      "change_pct": 3.1,
      "direction": "up"
    },
    "push_open_rate": {
      "value": 18.7,
      "change_pct": -0.5,
      "direction": "down"
    }
  },
  "generated_at": "2026-03-10T00:05:00Z"
}
```

**Implementation Notes:**
- `dau`: Count of distinct `device_id` in `events` table where `event_name = 'session_start'` for today.
- `d7_retention`: Percentage of users who installed 7 days ago and had a `session_start` today.
- `new_installs`: Count of `devices` created today.
- `onboarding_conversion`: `onboarding_completed` / `onboarding_started` events for the last 7 days.
- `change_pct`: Comparison with same metric from yesterday. Positive = growth.

**Error 500:**
```json
{
  "detail": "Failed to compute dashboard metrics"
}
```

---

## 2. Funnel Analysis

### GET /api/v1/admin/funnel

Returns 7-step onboarding funnel data for a date range.

**Required Role:** `ceo`, `cto`, `pm`

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| start_date | string (YYYY-MM-DD) | no | 7 days ago | Funnel period start |
| end_date | string (YYYY-MM-DD) | no | today | Funnel period end |

**Response 200:**
```json
{
  "start_date": "2026-03-03",
  "end_date": "2026-03-10",
  "total_users_in_range": 450,
  "steps": [
    {
      "step": 1,
      "name": "app_install",
      "event_name": null,
      "count": 450,
      "pct_of_total": 100.0,
      "drop_off_pct": 0.0
    },
    {
      "step": 2,
      "name": "onboarding_started",
      "event_name": "onboarding_started",
      "count": 420,
      "pct_of_total": 93.3,
      "drop_off_pct": 6.7
    },
    {
      "step": 3,
      "name": "etf_registered",
      "event_name": "etf_registered",
      "count": 380,
      "pct_of_total": 84.4,
      "drop_off_pct": 9.5
    },
    {
      "step": 4,
      "name": "push_permission_responded",
      "event_name": "push_permission_granted|push_permission_denied",
      "count": 350,
      "pct_of_total": 77.8,
      "drop_off_pct": 7.9
    },
    {
      "step": 5,
      "name": "onboarding_completed",
      "event_name": "onboarding_completed",
      "count": 302,
      "pct_of_total": 67.1,
      "drop_off_pct": 13.7
    },
    {
      "step": 6,
      "name": "first_briefing_viewed",
      "event_name": "briefing_viewed",
      "count": 245,
      "pct_of_total": 54.4,
      "drop_off_pct": 18.9
    },
    {
      "step": 7,
      "name": "day2_return",
      "event_name": "session_start (day >= install_date + 1)",
      "count": 198,
      "pct_of_total": 44.0,
      "drop_off_pct": 19.2
    }
  ]
}
```

**Implementation Notes:**
- Step 1 (app_install): Count of `devices.created_at` in range.
- Steps 2-6: Distinct `device_id` count from `events` table filtered by `event_name`.
- Step 7 (day2_return): Devices that had a `session_start` event on any day after their `devices.created_at` date.

**Error 400:**
```json
{
  "detail": "start_date must be before end_date"
}
```

---

## 3. Cohort Retention

### GET /api/v1/admin/retention

Returns a weekly cohort retention matrix (heatmap data).

**Required Role:** `ceo`, `cto`, `pm`

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| weeks | int | no | 8 | Number of cohort weeks to return (1-12) |

**Response 200:**
```json
{
  "weeks": 8,
  "cohorts": [
    {
      "cohort_week": "2026-W03",
      "cohort_start": "2026-01-13",
      "cohort_size": 120,
      "retention": [
        { "week": 0, "active": 120, "rate": 100.0 },
        { "week": 1, "active": 78, "rate": 65.0 },
        { "week": 2, "active": 54, "rate": 45.0 },
        { "week": 3, "active": 42, "rate": 35.0 },
        { "week": 4, "active": 36, "rate": 30.0 },
        { "week": 5, "active": 31, "rate": 25.8 },
        { "week": 6, "active": 28, "rate": 23.3 },
        { "week": 7, "active": 25, "rate": 20.8 }
      ]
    },
    {
      "cohort_week": "2026-W04",
      "cohort_start": "2026-01-20",
      "cohort_size": 95,
      "retention": [
        { "week": 0, "active": 95, "rate": 100.0 },
        { "week": 1, "active": 60, "rate": 63.2 }
      ]
    }
  ],
  "generated_at": "2026-03-10T00:05:00Z"
}
```

**Implementation Notes:**
- A "cohort" is defined by the ISO week of `devices.created_at`.
- "Active" in week N means the device had at least one `session_start` event during that ISO week.
- Weeks with no data yet are omitted from the `retention` array.

**Error 400:**
```json
{
  "detail": "weeks must be between 1 and 12"
}
```

---

## 4. Push Performance

### GET /api/v1/admin/push

Returns push notification performance metrics grouped by push type.

**Required Role:** `ceo`, `cto`, `pm`

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| start_date | string (YYYY-MM-DD) | no | 7 days ago | Period start |
| end_date | string (YYYY-MM-DD) | no | today | Period end |

**Response 200:**
```json
{
  "start_date": "2026-03-03",
  "end_date": "2026-03-10",
  "summary": {
    "total_sent": 5400,
    "total_delivered": 5100,
    "total_opened": 918,
    "overall_open_rate": 18.0
  },
  "by_type": [
    {
      "push_type": "morning_briefing",
      "sent": 2700,
      "delivered": 2550,
      "opened": 510,
      "open_rate": 20.0,
      "avg_time_to_open_seconds": 1200
    },
    {
      "push_type": "night_briefing",
      "sent": 2700,
      "delivered": 2550,
      "opened": 408,
      "open_rate": 16.0,
      "avg_time_to_open_seconds": 1800
    }
  ],
  "daily": [
    {
      "date": "2026-03-10",
      "sent": 780,
      "delivered": 740,
      "opened": 148,
      "open_rate": 20.0
    }
  ]
}
```

**Implementation Notes:**
- `sent`: Count of push send attempts (from push_log or FCM response tracking).
- `delivered`: Sent minus known failures (invalid tokens, errors).
- `opened`: Matched by `briefing_viewed` events with `view_source = "push_notification"`.
- Push type is inferred from the `data.briefing_type` field in the push payload.
- Requires a `push_logs` table (to be added in a future migration) or derived from events data.

---

## 5. User Statistics

### GET /api/v1/admin/users/stats

Returns aggregated user statistics.

**Required Role:** `ceo`, `cto`, `pm`

**Query Parameters:** None

**Response 200:**
```json
{
  "total_installs": 2500,
  "active_devices_7d": 890,
  "active_devices_30d": 1450,
  "push_enabled_count": 1800,
  "push_enabled_pct": 72.0,
  "etf_distribution": {
    "avg_etfs_per_user": 3.2,
    "median_etfs_per_user": 3,
    "histogram": [
      { "etf_count": 1, "users": 320 },
      { "etf_count": 2, "users": 450 },
      { "etf_count": 3, "users": 580 },
      { "etf_count": 4, "users": 410 },
      { "etf_count": 5, "users": 290 },
      { "etf_count": "6+", "users": 450 }
    ]
  },
  "platform_breakdown": [
    { "platform": "ios", "count": 1625, "pct": 65.0 },
    { "platform": "android", "count": 875, "pct": 35.0 }
  ],
  "top_etfs": [
    { "ticker": "SPY", "name": "SPDR S&P 500 ETF Trust", "registered_count": 890 },
    { "ticker": "QQQ", "name": "Invesco QQQ Trust", "registered_count": 720 },
    { "ticker": "ARKK", "name": "ARK Innovation ETF", "registered_count": 510 },
    { "ticker": "VTI", "name": "Vanguard Total Stock Market ETF", "registered_count": 480 },
    { "ticker": "SCHD", "name": "Schwab U.S. Dividend Equity ETF", "registered_count": 430 }
  ],
  "generated_at": "2026-03-10T00:05:00Z"
}
```

**Implementation Notes:**
- `total_installs`: Count of rows in `devices`.
- `active_devices_7d/30d`: Distinct `device_id` from `events` with `session_start` in the last 7/30 days.
- `push_enabled_count`: Devices with non-empty `push_token`.
- `etf_distribution`: Group by count from `device_etfs`.
- `platform_breakdown`: Group by `devices.platform`.
- `top_etfs`: Top 10 tickers from `device_etfs` joined with `etf_master`.

---

## 6. Event Explorer

### GET /api/v1/admin/events

Browse raw analytics events with filtering and pagination.

**Required Role:** `ceo`, `cto`, `pm`

**Query Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| event_name | string | no | null | Filter by event name (exact match) |
| device_id | string | no | null | Filter by device ID (exact match) |
| start_date | string (YYYY-MM-DD) | no | 24h ago | Period start |
| end_date | string (YYYY-MM-DD) | no | now | Period end |
| limit | int | no | 100 | Results per page (1-500) |
| offset | int | no | 0 | Pagination offset |

**Response 200:**
```json
{
  "events": [
    {
      "id": "evt_uuid_123",
      "device_id": "dev_abc123",
      "event_name": "briefing_viewed",
      "properties": {
        "briefing_id": "brief_20260310_abc",
        "view_source": "push_notification",
        "read_duration_seconds": 120
      },
      "event_timestamp": "2026-03-10T07:35:00Z",
      "received_at": "2026-03-10T07:35:01Z"
    }
  ],
  "total": 15234,
  "limit": 100,
  "offset": 0,
  "has_more": true
}
```

**Implementation Notes:**
- Queries the `events` table directly.
- Results are ordered by `event_timestamp DESC`.
- `total` is the count matching the filters (for pagination UI).

**Error 400:**
```json
{
  "detail": "limit must be between 1 and 500"
}
```

---

## 7. Deploy Approval

### POST /api/v1/admin/deploy/approve

Approve a release for deployment. Requires TOTP verification.

**Required Role:** `ceo`, `cto` only

**Request Body:**
```json
{
  "release_id": "rel_20260310_v1.2.0",
  "totp_code": "123456"
}
```

**Response 200:**
```json
{
  "release_id": "rel_20260310_v1.2.0",
  "approved_by": "ceo@portfiq.com",
  "role": "ceo",
  "totp_verified": true,
  "approved_at": "2026-03-10T14:00:00Z",
  "approvals_complete": false,
  "approvals": [
    { "role": "ceo", "approved": true, "approved_at": "2026-03-10T14:00:00Z" },
    { "role": "cto", "approved": false, "approved_at": null }
  ],
  "message": "Approval recorded. Waiting for cto approval."
}
```

**Response 200 (both approvals done):**
```json
{
  "release_id": "rel_20260310_v1.2.0",
  "approved_by": "cto@portfiq.com",
  "role": "cto",
  "totp_verified": true,
  "approved_at": "2026-03-10T14:05:00Z",
  "approvals_complete": true,
  "approvals": [
    { "role": "ceo", "approved": true, "approved_at": "2026-03-10T14:00:00Z" },
    { "role": "cto", "approved": true, "approved_at": "2026-03-10T14:05:00Z" }
  ],
  "message": "All approvals complete. Ready for deployment."
}
```

**Error 400 (invalid TOTP):**
```json
{
  "detail": "Invalid TOTP code"
}
```

**Error 403:**
```json
{
  "detail": "Insufficient permissions. Required role: ceo or cto"
}
```

**Error 404:**
```json
{
  "detail": "Release not found: rel_20260310_v1.2.0"
}
```

**Error 409:**
```json
{
  "detail": "Release already approved by ceo"
}
```

**Implementation Notes:**
- Dual approval required: both `ceo` and `cto` must approve before deploy is allowed.
- TOTP verification uses `pyotp` with the admin user's `totp_secret` from `admin_users`.
- Each role can only approve once per release (UNIQUE constraint on `deploy_approvals`).
- Release must be in `pending` or `approved` status to accept approvals.

---

## 8. Deploy Execute

### POST /api/v1/admin/deploy/execute

Trigger a GitHub Actions deployment workflow. Requires dual approval to be complete.

**Required Role:** `ceo`, `cto` only

**Request Body:**
```json
{
  "release_id": "rel_20260310_v1.2.0",
  "target_environment": "production",
  "totp_code": "654321"
}
```

**Response 200:**
```json
{
  "release_id": "rel_20260310_v1.2.0",
  "github_run_id": "12345678",
  "status": "deploying",
  "triggered_by": "cto@portfiq.com",
  "started_at": "2026-03-10T14:10:00Z",
  "message": "Deployment triggered. Monitor at /api/v1/admin/deploy/status/12345678"
}
```

**Error 400 (approvals incomplete):**
```json
{
  "detail": "Dual approval required. Missing approval from: cto"
}
```

**Error 400 (invalid TOTP):**
```json
{
  "detail": "Invalid TOTP code"
}
```

**Error 403:**
```json
{
  "detail": "Insufficient permissions. Required role: ceo or cto"
}
```

**Error 404:**
```json
{
  "detail": "Release not found: rel_20260310_v1.2.0"
}
```

**Error 409:**
```json
{
  "detail": "Release is already deploying or deployed"
}
```

**Implementation Notes:**
- Validates that both `ceo` and `cto` approvals exist in `deploy_approvals`.
- TOTP re-verification required at execution time (separate from approval TOTP).
- Triggers GitHub Actions workflow via `gh api` or GitHub REST API.
- `target_environment` must be one of: `staging`, `production`.
- Creates a row in `deploy_history` with `status = 'running'`.
- Returns the GitHub Actions `run_id` for status polling.

---

## 9. Deploy Status

### GET /api/v1/admin/deploy/status/{run_id}

Poll the status of a deployment.

**Required Role:** `ceo`, `cto`, `pm`

**Path Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| run_id | string | GitHub Actions run ID |

**Response 200 (in progress):**
```json
{
  "run_id": "12345678",
  "release_id": "rel_20260310_v1.2.0",
  "version": "1.2.0",
  "status": "deploying",
  "triggered_by": "cto@portfiq.com",
  "started_at": "2026-03-10T14:10:00Z",
  "completed_at": null,
  "duration_seconds": 120,
  "steps": [
    { "name": "build", "status": "completed", "duration_seconds": 45 },
    { "name": "test", "status": "completed", "duration_seconds": 60 },
    { "name": "deploy", "status": "in_progress", "duration_seconds": 15 }
  ]
}
```

**Response 200 (completed):**
```json
{
  "run_id": "12345678",
  "release_id": "rel_20260310_v1.2.0",
  "version": "1.2.0",
  "status": "deployed",
  "triggered_by": "cto@portfiq.com",
  "started_at": "2026-03-10T14:10:00Z",
  "completed_at": "2026-03-10T14:15:00Z",
  "duration_seconds": 300,
  "steps": [
    { "name": "build", "status": "completed", "duration_seconds": 45 },
    { "name": "test", "status": "completed", "duration_seconds": 60 },
    { "name": "deploy", "status": "completed", "duration_seconds": 195 }
  ]
}
```

**Response 200 (failed):**
```json
{
  "run_id": "12345678",
  "release_id": "rel_20260310_v1.2.0",
  "version": "1.2.0",
  "status": "failed",
  "triggered_by": "cto@portfiq.com",
  "started_at": "2026-03-10T14:10:00Z",
  "completed_at": "2026-03-10T14:12:00Z",
  "duration_seconds": 120,
  "error_log": "Deploy step failed: container health check timeout after 60s",
  "steps": [
    { "name": "build", "status": "completed", "duration_seconds": 45 },
    { "name": "test", "status": "completed", "duration_seconds": 60 },
    { "name": "deploy", "status": "failed", "duration_seconds": 15 }
  ]
}
```

**Error 404:**
```json
{
  "detail": "Deployment run not found: 12345678"
}
```

**Implementation Notes:**
- First checks `deploy_history` for the local record.
- Optionally fetches live status from GitHub Actions API: `GET /repos/{owner}/{repo}/actions/runs/{run_id}`.
- `steps` are derived from the GitHub Actions workflow jobs.
- Updates `deploy_history.status` and `deploy_releases.status` when terminal state is detected.

---

## Common Error Responses

All endpoints share these error formats:

| Status | Meaning | Body |
|--------|---------|------|
| 400 | Bad request | `{"detail": "Human-readable message"}` |
| 401 | Unauthorized | `{"detail": "Not authenticated"}` |
| 403 | Forbidden | `{"detail": "Insufficient permissions. Required role: ..."}` |
| 404 | Not found | `{"detail": "Resource not found: ..."}` |
| 409 | Conflict | `{"detail": "Conflict description"}` |
| 422 | Validation error | Pydantic validation error format |
| 429 | Rate limited | `{"detail": "Too many requests. Retry after 60 seconds"}` |
| 500 | Server error | `{"detail": "Internal server error"}` |

---

## Frontend Folder Structure

```
apps/admin/
├── app/
│   ├── (auth)/
│   │   └── login/
│   │       └── page.tsx                 # JWT login form
│   ├── (admin)/
│   │   ├── layout.tsx                   # Authenticated layout (sidebar, header, role guard)
│   │   ├── dashboard/
│   │   │   └── page.tsx                 # KPI cards + sparklines
│   │   ├── funnel/
│   │   │   └── page.tsx                 # 7-step funnel visualization
│   │   ├── retention/
│   │   │   └── page.tsx                 # Cohort heatmap matrix
│   │   ├── push/
│   │   │   └── page.tsx                 # Push performance charts
│   │   ├── users/
│   │   │   └── page.tsx                 # User stats, ETF distribution, platform pie
│   │   ├── events/
│   │   │   └── page.tsx                 # Raw event table with filters
│   │   └── deploy/
│   │       └── page.tsx                 # Release list, approval flow, TOTP modal, status
│   └── layout.tsx                       # Root layout (providers, fonts)
├── components/
│   ├── charts/
│   │   ├── KpiCard.tsx                  # Single KPI with delta indicator
│   │   ├── FunnelChart.tsx              # Horizontal bar funnel
│   │   ├── RetentionHeatmap.tsx         # Color-coded cohort grid
│   │   ├── LineChart.tsx                # Time series (DAU, push open rate)
│   │   ├── BarChart.tsx                 # Vertical/horizontal bars
│   │   └── PieChart.tsx                 # Platform breakdown, ETF distribution
│   ├── deploy/
│   │   ├── ApprovalCard.tsx             # Shows approval status per role
│   │   ├── TotpModal.tsx                # 6-digit TOTP input dialog
│   │   └── DeployStatus.tsx             # Polling status with step progress
│   ├── events/
│   │   └── EventTable.tsx               # Paginated event log table
│   └── ui/                              # shadcn/ui primitives
│       ├── button.tsx
│       ├── card.tsx
│       ├── dialog.tsx
│       ├── input.tsx
│       ├── select.tsx
│       ├── table.tsx
│       ├── badge.tsx
│       └── skeleton.tsx
├── lib/
│   ├── supabase.ts                      # Supabase client (if needed for realtime)
│   ├── admin-api.ts                     # API client with JWT interceptor
│   └── auth.ts                          # Login, token storage, role helpers
├── hooks/
│   ├── use-admin-auth.ts                # Auth state hook
│   └── use-polling.ts                   # Deploy status polling hook
├── types/
│   └── admin.ts                         # TypeScript interfaces for all API responses
├── tailwind.config.ts
├── next.config.ts
├── package.json
└── tsconfig.json
```

### Key Frontend Dependencies

| Package | Purpose |
|---------|---------|
| `next` (15+) | App Router framework |
| `react` (19+) | UI library |
| `tailwindcss` (4+) | Utility-first CSS |
| `shadcn/ui` | Component primitives |
| `recharts` | Chart library (KPI, funnel, heatmap, line, bar, pie) |
| `zustand` | Lightweight state management |
| `@tanstack/react-query` | Server state + polling |
| `zod` | Runtime type validation |

### Auth Flow

1. User visits `/login` -> enters email + password.
2. `POST /api/v1/admin/auth/login` returns JWT.
3. Token stored in `httpOnly` cookie (or localStorage for simplicity in MVP).
4. `(admin)/layout.tsx` checks token validity and role on every route.
5. Token expired -> redirect to `/login`.
6. Deploy pages check `role === 'ceo' || role === 'cto'` before rendering approval/execute buttons.

---

## Database Schema

See migration file: `backend/migrations/003_admin_deploy_tables.sql`

### Tables

| Table | Purpose |
|-------|---------|
| `admin_users` | Admin accounts with hashed passwords and TOTP secrets |
| `deploy_releases` | Release records with version, changelog, status |
| `deploy_approvals` | Per-role approval records with TOTP verification |
| `deploy_history` | Deployment execution history linked to GitHub Actions |

### Entity Relationship

```
admin_users (standalone)
  |
  +-- email referenced by deploy_approvals.approved_by
  +-- email referenced by deploy_history.triggered_by

deploy_releases
  |
  +-- deploy_approvals (1:N, one per role)
  +-- deploy_history (1:N, re-deploy attempts)
```

### Existing Tables Used by Analytics Endpoints

| Table | Used By |
|-------|---------|
| `devices` | Dashboard KPI, retention, user stats |
| `events` | Dashboard KPI, funnel, retention, event explorer |
| `device_etfs` | User stats (ETF distribution) |
| `etf_master` | User stats (top ETFs) |
| `daily_metrics` | Dashboard KPI (pre-aggregated) |

---

## Rate Limiting

| Endpoint Group | Limit |
|----------------|-------|
| Auth (login) | 5 requests/minute per IP |
| Read endpoints | 60 requests/minute per token |
| Deploy endpoints | 10 requests/minute per token |

---

## Environment Variables (New)

| Variable | Description | Required |
|----------|-------------|----------|
| `ADMIN_JWT_SECRET` | Secret key for HS256 JWT signing | Yes |
| `GITHUB_TOKEN` | GitHub PAT for triggering Actions workflows | Yes (deploy) |
| `GITHUB_REPO` | Repository in `owner/repo` format | Yes (deploy) |
| `GITHUB_WORKFLOW_ID` | Workflow file name (e.g., `deploy.yml`) | Yes (deploy) |
