"""ETF 실시간 가격 서비스 — yfinance 기반."""

import logging
import time

logger = logging.getLogger(__name__)

# In-memory price cache (15분 TTL)
_price_cache: dict[str, tuple[float, dict]] = {}  # ticker -> (expires_at, data)
_PRICE_TTL = 900  # 15분


def _get_cached_price(ticker: str) -> dict | None:
    """캐시에서 가격 조회."""
    entry = _price_cache.get(ticker)
    if entry is None:
        return None
    expires_at, data = entry
    if time.monotonic() > expires_at:
        del _price_cache[ticker]
        return None
    return data


def _cache_price(ticker: str, data: dict) -> None:
    """가격을 캐시에 저장."""
    _price_cache[ticker] = (time.monotonic() + _PRICE_TTL, data)


async def get_etf_price(ticker: str) -> dict:
    """ETF 현재가 및 등락률을 반환한다.

    Args:
        ticker: ETF 티커 (예: QQQ, VOO).

    Returns:
        {"ticker": str, "price": float, "change_pct": float, "change_amt": float, "currency": "USD"}
    """
    # Check cache
    cached = _get_cached_price(ticker)
    if cached:
        return cached

    try:
        import yfinance as yf

        stock = yf.Ticker(ticker)
        info = stock.fast_info

        current_price = float(info.get("lastPrice", 0) or info.get("last_price", 0))
        previous_close = float(info.get("previousClose", 0) or info.get("previous_close", 0))

        if current_price and previous_close:
            change_amt = round(current_price - previous_close, 2)
            change_pct = round((change_amt / previous_close) * 100, 2)
        else:
            change_amt = 0.0
            change_pct = 0.0

        result = {
            "ticker": ticker.upper(),
            "price": round(current_price, 2),
            "change_pct": change_pct,
            "change_amt": change_amt,
            "currency": "USD",
        }

        _cache_price(ticker, result)
        logger.info("가격 조회: %s = $%.2f (%.2f%%)", ticker, current_price, change_pct)
        return result

    except Exception as e:
        logger.warning("가격 조회 실패 (%s): %s — mock 데이터 반환", ticker, e)
        # Mock fallback
        mock = _get_mock_price(ticker)
        return mock


def _get_mock_price(ticker: str) -> dict:
    """Mock 가격 데이터."""
    mock_prices = {
        "QQQ": {"price": 485.23, "change_pct": 1.2, "change_amt": 5.73},
        "VOO": {"price": 532.10, "change_pct": 0.8, "change_amt": 4.21},
        "SPY": {"price": 578.45, "change_pct": 0.75, "change_amt": 4.31},
        "SCHD": {"price": 82.15, "change_pct": -0.3, "change_amt": -0.25},
        "TQQQ": {"price": 72.80, "change_pct": 3.6, "change_amt": 2.53},
        "SOXL": {"price": 28.45, "change_pct": 4.2, "change_amt": 1.15},
        "JEPI": {"price": 58.90, "change_pct": 0.1, "change_amt": 0.06},
        "ARKK": {"price": 52.30, "change_pct": 2.1, "change_amt": 1.08},
        "TLT": {"price": 88.75, "change_pct": -0.5, "change_amt": -0.45},
        "GLD": {"price": 215.60, "change_pct": 0.3, "change_amt": 0.64},
        "NVDA": {"price": 892.50, "change_pct": 2.8, "change_amt": 24.30},
    }
    data = mock_prices.get(ticker.upper(), {"price": 100.00, "change_pct": 0.0, "change_amt": 0.0})
    return {"ticker": ticker.upper(), **data, "currency": "USD"}


async def get_batch_prices(tickers: list[str]) -> list[dict]:
    """여러 ETF 가격을 일괄 조회한다.

    Args:
        tickers: 티커 리스트.

    Returns:
        가격 딕셔너리 리스트.
    """
    results = []
    for ticker in tickers:
        price = await get_etf_price(ticker)
        results.append(price)
    return results
