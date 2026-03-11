"""Pydantic schemas for request/response validation."""

from pydantic import BaseModel, Field


# ──────────────────────────────────────────────
# ETF
# ──────────────────────────────────────────────

class ETFRegisterRequest(BaseModel):
    """Request to register ETFs to a device's watchlist."""
    device_id: str
    tickers: list[str] = Field(..., min_length=1, max_length=20)


class ETFSearchResult(BaseModel):
    """Compact ETF search result."""
    ticker: str
    name: str
    name_kr: str | None = None
    category: str | None = None


class ETFInfo(BaseModel):
    """Full ETF detail with holdings and metadata."""
    ticker: str
    name: str
    name_kr: str | None = None
    description: str | None = None
    category: str | None = None
    expense_ratio: float | None = None
    top_holdings: list = Field(default_factory=list)


# ──────────────────────────────────────────────
# Device
# ──────────────────────────────────────────────

class DeviceRegisterRequest(BaseModel):
    """Request to register a device with push token."""
    device_id: str
    push_token: str = ""
    platform: str = ""
    app_version: str = ""


# ──────────────────────────────────────────────
# Feed
# ──────────────────────────────────────────────

class ETFImpact(BaseModel):
    """Impact assessment on a specific ETF."""
    etf_ticker: str
    level: str = Field(..., description="High / Medium / Low")


class FeedItem(BaseModel):
    """A single feed card item."""
    id: str
    headline: str
    impact_reason: str
    summary_3line: str = ""
    sentiment: str = "중립"  # 호재 / 중립 / 위험
    source: str | None = None
    source_url: str | None = None
    published_at: str | None = None
    impacts: list[ETFImpact] = Field(default_factory=list)


# ──────────────────────────────────────────────
# Briefing
# ──────────────────────────────────────────────

class ETFChange(BaseModel):
    """Single ETF price change in a briefing."""
    ticker: str
    change_pct: float
    direction: str = Field(..., description="up / down / flat")
    cause: str


class BriefingResponse(BaseModel):
    """Full briefing response (morning or night)."""
    type: str = Field(..., description="morning / night")
    title: str
    summary: str
    etf_changes: list[ETFChange] = Field(default_factory=list)
    checkpoints: list[str] = Field(default_factory=list)
    generated_at: str | None = None


# ──────────────────────────────────────────────
# Analytics
# ──────────────────────────────────────────────

class EventItem(BaseModel):
    """A single analytics event from the client."""
    name: str
    properties: dict = Field(default_factory=dict)
    timestamp: str


class EventBatchRequest(BaseModel):
    """Batch of analytics events from a device."""
    device_id: str
    events: list[EventItem]


# ──────────────────────────────────────────────
# Health
# ──────────────────────────────────────────────

class HealthResponse(BaseModel):
    """Health check response."""
    status: str
    version: str
    timestamp: str


# ──────────────────────────────────────────────
# Holdings
# ──────────────────────────────────────────────

class HoldingItem(BaseModel):
    """Single holding in an ETF."""
    name: str = ""
    ticker: str = ""
    weight: float = 0.0


class HoldingsResponse(BaseModel):
    """ETF holdings response."""
    ticker: str
    holdings: list[HoldingItem] = []
    total_holdings: int = 0
    as_of: str = ""


class CompanyEtfResult(BaseModel):
    """ETF that contains a specific company."""
    etf_ticker: str
    etf_name: str = ""
    weight: float = 0.0
