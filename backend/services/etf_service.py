"""ETF data service — search, details, and device registration management.

Uses Supabase as primary data store with in-memory fallback for resilience.
Loads name_kr mapping from seeds/etf_master.json for Korean name support.
Falls back to yfinance for ETFs not in the local master.
"""

from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timedelta
from pathlib import Path

from models.schemas import ETFInfo, ETFSearchResult

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# name_kr + structured holdings from JSON seed
# ──────────────────────────────────────────────

_NAME_KR_MAP: dict[str, str] = {}
_HOLDINGS_MAP: dict[str, list] = {}

def _load_seed_mappings() -> None:
    """Load name_kr and structured holdings from etf_master.json."""
    global _NAME_KR_MAP, _HOLDINGS_MAP
    json_path = Path(__file__).resolve().parent.parent / "seeds" / "etf_master.json"
    if not json_path.exists():
        return
    try:
        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)
        for etf in data:
            ticker = etf.get("ticker", "").upper()
            if ticker:
                _NAME_KR_MAP[ticker] = etf.get("name_kr", "")
                _HOLDINGS_MAP[ticker] = etf.get("top_holdings", [])
    except Exception as e:
        logger.warning("Failed to load seed mappings: %s", e)

_load_seed_mappings()

# ──────────────────────────────────────────────
# In-memory fallback ETF master data (auto-generated from JSON seed)
# ──────────────────────────────────────────────


def _build_etf_master_from_seed() -> dict[str, ETFInfo]:
    """Build ETF master dict from seeds/etf_master.json for fallback."""
    json_path = Path(__file__).resolve().parent.parent / "seeds" / "etf_master.json"
    if not json_path.exists():
        return {}
    try:
        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)
        result: dict[str, ETFInfo] = {}
        for etf in data:
            ticker = etf.get("ticker", "").upper()
            if ticker:
                result[ticker] = ETFInfo(
                    ticker=ticker,
                    name=etf.get("name", ""),
                    name_kr=etf.get("name_kr"),
                    description=etf.get("name_kr", ""),
                    category=etf.get("category"),
                    expense_ratio=etf.get("expense_ratio"),
                    top_holdings=etf.get("top_holdings", []),
                )
        return result
    except Exception as e:
        logger.warning("Failed to build ETF master from seed: %s", e)
        return {}


_ETF_MASTER: dict[str, ETFInfo] = _build_etf_master_from_seed()

# ──────────────────────────────────────────────
# yfinance dynamic lookup (fallback for unknown tickers)
# ──────────────────────────────────────────────

_yf_cache: dict[str, tuple[datetime, ETFInfo | None]] = {}
_YF_CACHE_TTL = timedelta(hours=24)
_YF_LOOKUP_TIMEOUT = 4  # yfinance info 호출 타임아웃 (초) — 8s → 4s로 단축


def _lookup_yfinance_sync(ticker: str) -> ETFInfo | None:
    """Look up ETF info from yfinance synchronously (runs in thread pool).

    Args:
        ticker: ETF ticker symbol.

    Returns:
        ETFInfo if found, None otherwise.
    """
    import yfinance as yf

    t = yf.Ticker(ticker)
    info = t.info
    if not info or not info.get("shortName"):
        return None

    return ETFInfo(
        ticker=ticker.upper(),
        name=info.get("shortName", ""),
        name_kr=None,
        description=info.get("longName", ""),
        category=info.get("category", info.get("quoteType", "")),
        expense_ratio=info.get("annualReportExpenseRatio"),
        top_holdings=[],
    )


async def _lookup_yfinance(ticker: str) -> ETFInfo | None:
    """Look up ETF info from yfinance when not in local master.

    Results are cached for 24 hours to avoid repeated API calls.
    Runs in a thread pool with timeout to avoid blocking the event loop.

    Args:
        ticker: ETF ticker symbol.

    Returns:
        ETFInfo if found, None otherwise.
    """
    now = datetime.utcnow()
    cached = _yf_cache.get(ticker.upper())
    if cached and (now - cached[0]) < _YF_CACHE_TTL:
        return cached[1]

    try:
        result = await asyncio.wait_for(
            asyncio.to_thread(_lookup_yfinance_sync, ticker),
            timeout=_YF_LOOKUP_TIMEOUT,
        )
        _yf_cache[ticker.upper()] = (now, result)
        return result
    except asyncio.TimeoutError:
        logger.warning("yfinance lookup timed out for %s (%ds)", ticker, _YF_LOOKUP_TIMEOUT)
        _yf_cache[ticker.upper()] = (now, None)
        return None
    except Exception as e:
        logger.warning("yfinance lookup failed for %s: %s", ticker, e)
        _yf_cache[ticker.upper()] = (now, None)
        return None


_POPULAR_TICKERS = ["QQQ", "VOO", "SCHD", "TQQQ", "SOXL", "JEPI", "SPY", "IVV", "VTI", "ARKK"]

# In-memory device -> ETF registration (fallback)
_device_etfs: dict[str, list[str]] = {}


def _get_sb():
    """Lazy-load Supabase client to avoid import errors when not configured."""
    try:
        from services.supabase_client import get_supabase
        return get_supabase()
    except Exception as e:
        logger.warning("Supabase client unavailable: %s", e)
        return None


class EtfService:
    """Manages ETF data, search, and device-ETF registration.

    Uses Supabase as primary data store. Falls back to in-memory mock data
    if Supabase is unavailable or queries fail.
    """

    async def search(self, query: str, limit: int = 20) -> list[ETFSearchResult]:
        """Search ETFs by name, ticker, or category (case-insensitive).

        Uses in-memory _ETF_MASTER (loaded from seeds/etf_master.json) as
        the primary search source for reliability. Also searches name_kr.

        Args:
            query: Search string to match against ticker, name, name_kr, or category.
            limit: Maximum number of results to return.

        Returns:
            List of matching ETFSearchResult objects.
        """
        q = query.strip()
        q_upper = q.upper()
        q_lower = q.lower()
        results: list[ETFSearchResult] = []
        for ticker, info in _ETF_MASTER.items():
            name_kr = _NAME_KR_MAP.get(ticker, "")
            if (
                q_upper in ticker
                or q_lower in info.name.lower()
                or (info.category and q_lower in info.category.lower())
                or (name_kr and q in name_kr)
            ):
                results.append(
                    ETFSearchResult(
                        ticker=info.ticker, name=info.name,
                        name_kr=name_kr or None,
                        category=info.category,
                    )
                )
            if len(results) >= limit:
                break
        return results

    async def get_detail(self, ticker: str) -> ETFInfo | None:
        """Get detailed ETF information including holdings.

        Uses TTL cache (15분) to avoid repeated Supabase/yfinance calls.
        Priority: cache → in-memory master → Supabase → yfinance (4s timeout).

        Args:
            ticker: ETF ticker symbol.

        Returns:
            ETFInfo if found, None otherwise.
        """
        from services.cache import get_cached, set_cached

        t = ticker.upper()
        cache_key = f"etf_detail_{t}"
        cached = get_cached(cache_key)
        if cached is not None:
            return cached

        # 1. In-memory master (가장 빠름 — JSON seed에서 로드)
        info = _ETF_MASTER.get(t)
        if info:
            set_cached(cache_key, info)
            return info

        # 2. Supabase
        sb = _get_sb()
        if sb is not None:
            try:
                resp = (
                    sb.table("etf_master")
                    .select("*")
                    .eq("ticker", t)
                    .limit(1)
                    .execute()
                )
                if resp.data:
                    row = resp.data[0]
                    # Prefer structured holdings from JSON seed
                    holdings = _HOLDINGS_MAP.get(t, row.get("top_holdings", []))
                    result = ETFInfo(
                        ticker=row["ticker"],
                        name=row["name"],
                        name_kr=_NAME_KR_MAP.get(t),
                        description=row.get("description", ""),
                        category=row.get("category"),
                        expense_ratio=row.get("expense_ratio"),
                        top_holdings=holdings or [],
                    )
                    set_cached(cache_key, result)
                    return result
                logger.info("ETF '%s' not in Supabase, trying yfinance", ticker)
            except Exception as e:
                logger.warning("Supabase get_detail failed, falling back to yfinance: %s", e)

        # 3. Final fallback: yfinance dynamic lookup (4s timeout)
        result = await _lookup_yfinance(ticker)
        if result:
            set_cached(cache_key, result)
        return result

    async def get_popular(self) -> list[ETFSearchResult]:
        """Return the top 10 popular ETFs based on device registration count.

        Results are cached for 15 minutes to avoid repeated Supabase/API calls.

        Returns:
            List of ETFSearchResult ordered by popularity.
        """
        from services.cache import get_cached, set_cached

        cache_key = "etf_popular"
        cached = get_cached(cache_key)
        if cached is not None:
            logger.debug("Cache hit for %s", cache_key)
            return cached

        sb = _get_sb()
        if sb is not None:
            try:
                # Get tickers ordered by registration count
                resp = (
                    sb.rpc(
                        "get_popular_etfs",
                        {"lim": 10},
                    ).execute()
                )
                if resp.data:
                    results = [
                        ETFSearchResult(
                            ticker=row["ticker"],
                            name=row["name"],
                            category=row.get("category"),
                        )
                        for row in resp.data
                    ]
                    set_cached(cache_key, results)
                    return results
                # If RPC doesn't exist or returns empty, try simple query
                resp = (
                    sb.table("etf_master")
                    .select("ticker, name, category")
                    .limit(10)
                    .execute()
                )
                results = [
                    ETFSearchResult(
                        ticker=row["ticker"],
                        name=row["name"],
                        name_kr=_NAME_KR_MAP.get(row["ticker"].upper()),
                        category=row.get("category"),
                    )
                    for row in resp.data
                ]
                set_cached(cache_key, results)
                return results
            except Exception as e:
                logger.warning("Supabase get_popular failed, falling back to mock: %s", e)

        # Fallback
        results: list[ETFSearchResult] = []
        for t in _POPULAR_TICKERS:
            info = _ETF_MASTER.get(t)
            if info:
                results.append(ETFSearchResult(
                    ticker=info.ticker, name=info.name,
                    name_kr=_NAME_KR_MAP.get(t),
                    category=info.category,
                ))
        set_cached(cache_key, results)
        return results

    async def register_etfs(self, device_id: str, tickers: list[str]) -> list[str]:
        """Register ETFs to a device's watchlist.

        Args:
            device_id: Device identifier.
            tickers: List of ETF ticker symbols to register.

        Returns:
            List of successfully registered ticker symbols.
        """
        normalised = [t.upper() for t in tickers]

        sb = _get_sb()
        if sb is not None:
            try:
                # Upsert device
                sb.table("devices").upsert(
                    {"device_id": device_id}, on_conflict="device_id"
                ).execute()

                # Insert device_etfs (ignore duplicates)
                rows = [{"device_id": device_id, "ticker": t} for t in normalised]
                sb.table("device_etfs").upsert(
                    rows, on_conflict="device_id,ticker"
                ).execute()

                logger.info("Device %s registered ETFs via Supabase: %s", device_id, normalised)
                return normalised
            except Exception as e:
                logger.warning("Supabase register_etfs failed, falling back to mock: %s", e)

        # Fallback
        valid = [t for t in normalised if t in _ETF_MASTER]
        _device_etfs[device_id] = valid
        logger.info("Device %s registered ETFs (mock): %s", device_id, valid)
        return valid

    async def get_registered(self, device_id: str) -> list[str]:
        """Get all registered ETF tickers for a device.

        Args:
            device_id: Device identifier.

        Returns:
            List of registered ticker symbols.
        """
        sb = _get_sb()
        if sb is not None:
            try:
                resp = (
                    sb.table("device_etfs")
                    .select("ticker")
                    .eq("device_id", device_id)
                    .execute()
                )
                return [row["ticker"] for row in resp.data]
            except Exception as e:
                logger.warning("Supabase get_registered failed, falling back to mock: %s", e)

        # Fallback
        return _device_etfs.get(device_id, [])

    async def unregister_etf(self, device_id: str, ticker: str) -> bool:
        """Remove an ETF from a device's watchlist.

        Args:
            device_id: Device identifier.
            ticker: ETF ticker symbol to remove.

        Returns:
            True if the ETF was removed, False if it wasn't registered.
        """
        t = ticker.upper()

        sb = _get_sb()
        if sb is not None:
            try:
                resp = (
                    sb.table("device_etfs")
                    .delete()
                    .eq("device_id", device_id)
                    .eq("ticker", t)
                    .execute()
                )
                deleted = len(resp.data) > 0 if resp.data else False
                if deleted:
                    logger.info("Device %s unregistered %s via Supabase", device_id, t)
                return deleted
            except Exception as e:
                logger.warning("Supabase unregister_etf failed, falling back to mock: %s", e)

        # Fallback
        tickers = _device_etfs.get(device_id, [])
        if t in tickers:
            tickers.remove(t)
            return True
        return False


etf_service = EtfService()
