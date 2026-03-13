"""USD/KRW 환율 서비스 — yfinance 기반.

환율은 30분 캐시로 관리하며, 실패 시 stale 캐시 또는 하드코딩 기본값을 반환한다.
"""

import asyncio
import logging
import time

logger = logging.getLogger(__name__)

_rate_cache: tuple[float, float] | None = None  # (expires_at, rate)
_RATE_TTL = 1800  # 30분
_stale_rate: float = 1350.0  # 기본 환율 (캐시 실패 시)


def _fetch_rate_sync() -> float:
    """yfinance에서 USD/KRW 환율을 동기적으로 조회한다."""
    import yfinance as yf

    ticker = yf.Ticker("KRW=X")
    info = ticker.fast_info
    rate = float(info.get("lastPrice", 0) or info.get("last_price", 0))
    if rate <= 0:
        raise ValueError(f"Invalid exchange rate: {rate}")
    return rate


async def get_usd_krw_rate() -> float:
    """USD/KRW 환율을 반환한다.

    30분 캐시, 실패 시 stale 캐시 또는 기본값 반환.

    Returns:
        USD/KRW 환율 (예: 1350.5).
    """
    global _rate_cache, _stale_rate

    # Check cache
    if _rate_cache is not None:
        expires_at, rate = _rate_cache
        if time.monotonic() < expires_at:
            return rate

    try:
        rate = await asyncio.wait_for(
            asyncio.to_thread(_fetch_rate_sync),
            timeout=10,
        )
        _rate_cache = (time.monotonic() + _RATE_TTL, rate)
        _stale_rate = rate
        logger.info("환율 조회: USD/KRW = %.2f", rate)
        return rate
    except Exception as e:
        logger.warning("환율 조회 실패: %s — stale 값 사용 (%.2f)", e, _stale_rate)
        return _stale_rate
