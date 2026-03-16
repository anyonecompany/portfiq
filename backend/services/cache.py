"""In-memory TTL cache utilities for expensive API calls.

Provides a thread-safe TTLCache wrapper to avoid repeated calls to
Gemini API, Supabase, and other slow external services.

Usage:
    from services.cache import get_cached, set_cached, clear_cache

    result = get_cached("etf_popular")
    if result is None:
        result = await expensive_call()
        set_cached("etf_popular", result)
"""

from __future__ import annotations

import logging
import threading
from typing import Any

from cachetools import TTLCache

logger = logging.getLogger(__name__)

# In-memory cache: max 100 entries, TTL 15 minutes (900 seconds)
_cache: TTLCache[str, Any] = TTLCache(maxsize=100, ttl=900)
_cache_lock = threading.Lock()


def get_cached(key: str) -> Any | None:
    """Retrieve a value from the cache.

    Args:
        key: Cache key string.

    Returns:
        Cached value if present and not expired, None otherwise.
    """
    with _cache_lock:
        return _cache.get(key)


def set_cached(key: str, value: Any) -> None:
    """Store a value in the cache.

    Args:
        key: Cache key string.
        value: Value to cache.
    """
    with _cache_lock:
        _cache[key] = value


def clear_cache() -> int:
    """Clear all entries from the cache.

    Returns:
        Number of entries that were cleared.
    """
    with _cache_lock:
        count = len(_cache)
        _cache.clear()
        logger.info("Cache cleared: %d entries removed", count)
        return count


def get_cache_stats() -> dict[str, Any]:
    """Return cache statistics for monitoring.

    Returns:
        Dict with current_size, max_size, ttl_seconds, and keys.
    """
    with _cache_lock:
        return {
            "current_size": len(_cache),
            "max_size": _cache.maxsize,
            "ttl_seconds": int(_cache.ttl),
            "keys": list(_cache.keys()),
        }
