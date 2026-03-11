"""Admin 인증 미들웨어 — Supabase Auth (Google OAuth) 기반.

Supabase access_token을 검증하고 이메일 화이트리스트 + 역할 매핑을 수행한다.
기존 ADMIN_JWT_SECRET 방식도 폴백으로 유지한다.
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import settings

logger = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer(auto_error=False)


def _verify_supabase_token(token: str) -> dict[str, Any]:
    """Supabase access_token을 검증하고 사용자 정보를 반환한다.

    Args:
        token: Supabase Auth가 발급한 JWT access_token.

    Returns:
        사용자 정보 딕셔너리 (email, role 등).

    Raises:
        HTTPException: 토큰 검증 실패 또는 화이트리스트 미포함 시.
    """
    try:
        from services.supabase_client import get_supabase_service
        sb = get_supabase_service()
        user_response = sb.auth.get_user(token)
        user = user_response.user

        if not user or not user.email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: no user found",
            )

        email = user.email.lower().strip()

        # 이메일 화이트리스트 체크
        allowed = [e.lower().strip() for e in settings.ADMIN_ALLOWED_EMAILS]
        if email not in allowed:
            logger.warning("Unauthorized admin access attempt: %s", email)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Email '{email}' is not authorized.",
            )

        # 역할 매핑
        role = settings.ADMIN_ROLE_MAP.get(email, "viewer")

        return {
            "sub": user.id,
            "email": email,
            "role": role,
            "auth_method": "supabase",
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.warning("Supabase token verification failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token verification failed",
        )


def _verify_legacy_jwt(token: str) -> dict[str, Any]:
    """기존 ADMIN_JWT_SECRET 기반 JWT 검증 (폴백).

    Args:
        token: HS256 JWT 토큰.

    Returns:
        JWT 클레임 딕셔너리.

    Raises:
        HTTPException: 검증 실패 시.
    """
    import os

    import jwt as pyjwt

    secret = getattr(settings, "ADMIN_JWT_SECRET", "") or os.getenv("ADMIN_JWT_SECRET", "")
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Legacy JWT auth not configured",
        )

    try:
        payload = pyjwt.decode(token, secret, algorithms=["HS256"])
        return payload
    except pyjwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
        )
    except pyjwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )


async def get_current_admin(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> dict[str, Any]:
    """현재 인증된 관리자 정보를 반환한다.

    Authorization Bearer 헤더 → HttpOnly 쿠키 순으로 토큰을 읽는다.
    Supabase Auth 검증을 시도하고, 실패 시 기존 JWT 폴백.

    Args:
        request: FastAPI Request.
        credentials: HTTP Bearer 인증 정보.

    Returns:
        관리자 정보 딕셔너리 (sub, email, role 등).

    Raises:
        HTTPException: 인증 실패 시 401/403.
    """
    # 1) Authorization 헤더에서 토큰 읽기
    token = None
    if credentials is not None:
        token = credentials.credentials
    # 2) 없으면 HttpOnly 쿠키 폴백
    if not token:
        token = request.cookies.get("portfiq_admin_token")
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )

    # Supabase Auth 토큰 검증 시도
    try:
        return _verify_supabase_token(token)
    except HTTPException as e:
        if e.status_code == 403:
            raise  # 화이트리스트 거부는 바로 반환
        # Supabase 검증 실패 → 기존 JWT 폴백
        try:
            return _verify_legacy_jwt(token)
        except HTTPException:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Not authenticated",
            )


def require_roles(*allowed_roles: str):
    """특정 역할만 접근 가능하도록 제한하는 의존성 팩토리.

    Args:
        *allowed_roles: 허용할 역할 목록 (예: "ceo", "cto").

    Returns:
        FastAPI 의존성 함수.
    """

    async def _check_role(
        admin: dict[str, Any] = Depends(get_current_admin),
    ) -> dict[str, Any]:
        role = admin.get("role", "")
        if role not in allowed_roles:
            roles_str = " or ".join(allowed_roles)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Insufficient permissions. Required role: {roles_str}",
            )
        return admin

    return _check_role
