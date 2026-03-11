"""Supabase 클라이언트 싱글톤."""

from __future__ import annotations

import logging

from supabase import create_client, Client

from config import settings

logger = logging.getLogger(__name__)

_client: Client | None = None
_service_client: Client | None = None


def get_supabase() -> Client:
    """Supabase 클라이언트 싱글톤 반환 (anon key).

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


def get_supabase_service() -> Client:
    """Supabase service_role 클라이언트 싱글톤 반환 (RLS 우회).

    서버사이드 데이터 삽입/수정 시 사용한다.
    SUPABASE_SERVICE_KEY가 없으면 anon key 클라이언트로 폴백한다.

    Returns:
        Supabase Client 인스턴스 (service_role 또는 anon 폴백).
    """
    global _service_client
    if _service_client is None:
        if not settings.SUPABASE_URL:
            raise ValueError("SUPABASE_URL must be set in environment variables.")
        if settings.SUPABASE_SERVICE_KEY:
            _service_client = create_client(
                settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY
            )
            logger.info("Supabase service client initialized (service_role)")
        else:
            logger.warning("SUPABASE_SERVICE_KEY not set, falling back to anon key")
            _service_client = get_supabase()
    return _service_client
