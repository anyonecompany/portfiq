"""ETF Holdings service — fetch and cache ETF constituent data.

Uses etf_master.json seed data as primary source, with yfinance as
fallback for ETFs not in the seed. Results are cached for 24 hours.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path

logger = logging.getLogger(__name__)

# In-memory cache: ticker -> (timestamp, holdings_data)
_holdings_cache: dict[str, tuple[datetime, dict]] = {}
_CACHE_TTL = timedelta(hours=24)


def _load_seed_holdings() -> dict[str, list[dict]]:
    """Load holdings from etf_master.json seed file."""
    json_path = Path(__file__).resolve().parent.parent / "seeds" / "etf_master.json"
    if not json_path.exists():
        return {}
    try:
        with open(json_path, encoding="utf-8") as f:
            data = json.load(f)
        result: dict[str, list[dict]] = {}
        for etf in data:
            ticker = etf.get("ticker", "").upper()
            holdings = etf.get("top_holdings", [])
            if ticker and holdings:
                result[ticker] = holdings
        return result
    except Exception as e:
        logger.warning("Failed to load seed holdings: %s", e)
        return {}


_SEED_HOLDINGS = _load_seed_holdings()


def _fetch_yfinance_holdings(ticker: str) -> list[dict] | None:
    """Fetch holdings from yfinance for ETFs not in seed data."""
    try:
        import yfinance as yf

        t = yf.Ticker(ticker)

        # Try newer API first
        try:
            holdings_df = t.funds_data.top_holdings
            if holdings_df is not None and not holdings_df.empty:
                result = []
                for symbol, row in holdings_df.iterrows():
                    result.append({
                        "name": str(row.get("Name", symbol)),
                        "ticker": str(symbol).replace(".US", ""),
                        "weight": round(float(row.get("Holding Percent", 0)) * 100, 2),
                    })
                return result[:20]  # Top 20
        except Exception:
            pass

        # Fallback: no other reliable yfinance attribute for holdings
        return None
    except Exception as e:
        logger.warning("yfinance holdings fetch failed for %s: %s", ticker, e)
        return None


class HoldingsService:
    """Service for fetching ETF holdings/constituents."""

    async def get_holdings(self, ticker: str) -> dict:
        """Get holdings for an ETF.

        Args:
            ticker: ETF ticker symbol.

        Returns:
            Dict with ticker, holdings list, total_holdings count, and as_of date.
        """
        t = ticker.upper()
        now = datetime.now(timezone.utc)

        # Check cache
        cached = _holdings_cache.get(t)
        if cached and (now - cached[0]) < _CACHE_TTL:
            return cached[1]

        holdings: list[dict] = []

        # Try seed data first
        seed = _SEED_HOLDINGS.get(t)
        if seed:
            holdings = seed
        else:
            # Try yfinance
            yf_holdings = _fetch_yfinance_holdings(t)
            if yf_holdings:
                holdings = yf_holdings

        result = {
            "ticker": t,
            "holdings": holdings,
            "total_holdings": len(holdings),
            "as_of": now.strftime("%Y-%m-%d"),
        }

        # Cache the result
        _holdings_cache[t] = (now, result)
        return result

    async def search_by_company(self, company_ticker: str) -> list[dict]:
        """Find ETFs that contain a specific company/stock.

        Args:
            company_ticker: Stock ticker to search for (e.g., "AAPL").

        Returns:
            List of dicts with etf_ticker and weight.
        """
        company = company_ticker.upper()
        results = []

        for etf_ticker, holdings in _SEED_HOLDINGS.items():
            for h in holdings:
                h_ticker = h.get("ticker", "").upper() if isinstance(h, dict) else ""
                if h_ticker == company:
                    weight = h.get("weight", 0) if isinstance(h, dict) else 0
                    results.append({
                        "etf_ticker": etf_ticker,
                        "etf_name": "",  # Will be filled by router
                        "weight": weight,
                    })
                    break

        # Sort by weight descending
        results.sort(key=lambda x: x.get("weight", 0), reverse=True)
        return results


holdings_service = HoldingsService()
