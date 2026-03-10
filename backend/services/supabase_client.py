"""Supabase 클라이언트 싱글톤."""

from __future__ import annotations

import logging

from supabase import create_client, Client

from config import settings

logger = logging.getLogger(__name__)

_client: Client | None = None


def get_supabase() -> Client:
    """Supabase 클라이언트 싱글톤 반환.

    Returns:
        Supabase Client 인스턴스.

    Raises:
        ValueError: SUPABASE_URL 또는 SUPABASE_KEY가 설정되지 않은 경우.
    """
    global _client
    if _client is None:
        if not settings.SUPABASE_URL or not settings.SUPABASE_KEY:
            raise ValueError(
                "SUPABASE_URL and SUPABASE_KEY must be set in environment variables."
            )
        _client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        logger.info("Supabase client initialized for %s", settings.SUPABASE_URL)
    return _client
