"""Rate limiting 미들웨어 — slowapi 기반.

엔드포인트별 요청 빈도를 제한하여 브루트포스 공격, API 남용을 방지한다.
"""

from __future__ import annotations

from slowapi import Limiter
from slowapi.util import get_remote_address
from starlette.requests import Request


def _key_func(request: Request) -> str:
    """요청 식별 키를 반환한다. X-Device-ID 또는 클라이언트 IP 기반.

    Args:
        request: Starlette Request 객체.

    Returns:
        Rate limit 식별 키 문자열.
    """
    device_id = request.headers.get("X-Device-ID")
    if device_id:
        return f"device:{device_id}"
    return get_remote_address(request)


limiter = Limiter(key_func=_key_func)

# 엔드포인트별 rate limit 상수
RATE_LOGIN = "30/minute"
RATE_DEPLOY = "10/minute"
RATE_ANALYTICS = "100/minute"
RATE_ADMIN_READ = "30/minute"
RATE_PUSH_SEND = "10/minute"
RATE_DEFAULT = "60/minute"
