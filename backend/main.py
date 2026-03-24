"""Portfiq API — AI-powered ETF briefing service."""

import logging
import sys
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from config import settings
from middleware.rate_limit import limiter
from models.schemas import HealthResponse
from routers import (
    feed,
    briefing,
    etf,
    etf_analysis,
    holdings,
    analytics,
    admin,
    devices,
    calendar,
)

# ──────────────────────────────────────────────
# Logging
# ──────────────────────────────────────────────

logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("portfiq")


# ──────────────────────────────────────────────
# Lifespan
# ──────────────────────────────────────────────


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan: startup and shutdown logic."""
    logger.info("Portfiq API starting in %s mode", settings.ENVIRONMENT)
    logger.info("CORS origins: %s", settings.CORS_ORIGINS)
    logger.info(
        "Briefing schedule: morning %02d:%02d, night %02d:00",
        settings.BRIEFING_MORNING_HOUR,
        settings.BRIEFING_MORNING_MINUTE,
        settings.BRIEFING_NIGHT_HOUR,
    )

    # GEMINI_API_KEY 설정 확인 (Fly.io 디버깅용)
    if settings.GEMINI_API_KEY:
        masked = settings.GEMINI_API_KEY[:8] + "..." + settings.GEMINI_API_KEY[-4:]
        logger.info(
            "GEMINI_API_KEY 설정됨: %s (len=%d)", masked, len(settings.GEMINI_API_KEY)
        )
    else:
        logger.warning("GEMINI_API_KEY 미설정 — 브리핑/번역이 mock 모드로 동작합니다")

    # Initialize Firebase Admin SDK (non-blocking)
    try:
        from services.push_service import init_firebase

        init_firebase()
    except Exception as e:
        logger.warning("Firebase 초기화 실패 (푸시 비활성): %s", e)

    # Start background scheduler (news collection + briefing generation)
    from jobs.briefing_scheduler import start_scheduler, stop_scheduler

    start_scheduler()

    yield

    # Stop scheduler gracefully
    stop_scheduler()
    logger.info("Portfiq API shutting down")


# ──────────────────────────────────────────────
# App
# ──────────────────────────────────────────────

app = FastAPI(
    title="Portfiq API",
    description="AI-powered ETF briefing backend",
    version="1.0.0",
    lifespan=lifespan,
)

# Rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS — allow Vercel preview URLs (*.vercel.app) dynamically
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https://.*\.vercel\.app",
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(etf.router, prefix="/api/v1/etf", tags=["ETF"])
app.include_router(etf_analysis.router, prefix="/api/v1/etf", tags=["ETF Analysis"])
app.include_router(holdings.router, prefix="/api/v1/holdings", tags=["Holdings"])
app.include_router(feed.router, prefix="/api/v1/feed", tags=["Feed"])
app.include_router(briefing.router, prefix="/api/v1/briefing", tags=["Briefing"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])
app.include_router(admin.router, prefix="/api/v1/admin", tags=["Admin"])
app.include_router(devices.router, prefix="/api/v1/devices", tags=["Devices"])
app.include_router(calendar.router, prefix="/api/v1/calendar", tags=["Calendar"])


# ──────────────────────────────────────────────
# Health check
# ──────────────────────────────────────────────


@app.get("/health", tags=["Health"])
async def health_root() -> dict:
    """Lightweight health check for Railway / load balancer probes."""
    return {"status": "ok", "version": "1.0.0", "environment": settings.ENVIRONMENT}


@app.get("/api/health", response_model=HealthResponse, tags=["Health"])
async def health_check() -> HealthResponse:
    """Health check endpoint with detailed info."""
    from services.analytics_service import analytics_service

    event_count = analytics_service.get_event_count()
    logger.debug("Health check — events stored: %d", event_count)
    return HealthResponse(
        status="ok",
        version="1.0.0",
        timestamp=datetime.now(timezone.utc).isoformat(),
    )
