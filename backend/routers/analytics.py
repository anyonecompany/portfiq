"""Analytics router — event tracking from client devices."""

import logging

from fastapi import APIRouter, Header, HTTPException, Request

from middleware.rate_limit import limiter, RATE_ANALYTICS
from models.schemas import EventBatchRequest
from services.analytics_service import analytics_service

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/events", status_code=202)
@limiter.limit(RATE_ANALYTICS)
async def track_events_batch(
    request: Request,
    body: EventBatchRequest,
    x_device_id: str | None = Header(None, alias="X-Device-ID"),
) -> dict:
    """Receive a batch of analytics events from a client device.

    Validates X-Device-ID header and stores events in memory.
    Returns 202 Accepted with count of events received.
    """
    device_id = x_device_id or body.device_id
    if not device_id:
        raise HTTPException(
            status_code=400,
            detail="X-Device-ID header or device_id in body is required",
        )

    events_data = [e.model_dump() for e in body.events]
    count = await analytics_service.store_events(device_id, events_data)

    logger.info("Received %d events from device %s", count, device_id)
    return {
        "status": "accepted",
        "count": count,
        "accepted": count,
    }
