"""Admin 인증 미들웨어 — JWT Bearer 토큰 검증.

ADMIN_JWT_SECRET 환경변수로 HS256 JWT를 검증하고,
역할 기반 접근 제어(RBAC)를 제공한다.
"""

from __future__ import annotations

import logging
from typing import Any

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from config import settings

logger = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer(auto_error=False)

# 환경변수에서 JWT 시크릿 로드
_JWT_SECRET: str = getattr(settings, "ADMIN_JWT_SECRET", "") or ""
_JWT_ALGORITHM = "HS256"


def _get_jwt_secret() -> str:
    """JWT 시크릿을 반환한다. 미설정 시 환경변수에서 직접 조회한다.

    Returns:
        JWT 서명 검증에 사용할 시크릿 문자열.

    Raises:
        HTTPException: 시크릿이 설정되지 않은 경우.
    """
    import os

    secret = _JWT_SECRET or os.getenv("ADMIN_JWT_SECRET", "")
    if not secret:
        logger.error("ADMIN_JWT_SECRET 환경변수가 설정되지 않았습니다")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Admin authentication is not configured",
        )
    return secret


def _decode_token(token: str) -> dict[str, Any]:
    """JWT 토큰을 디코드하고 검증한다.

    Args:
        token: Bearer 토큰 문자열.

    Returns:
        디코드된 JWT 클레임 딕셔너리.

    Raises:
        HTTPException: 토큰이 유효하지 않거나 만료된 경우.
    """
    secret = _get_jwt_secret()
    try:
        payload = jwt.decode(token, secret, algorithms=[_JWT_ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
        )
    except jwt.InvalidTokenError as e:
        logger.warning("JWT 검증 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )


async def get_current_admin(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> dict[str, Any]:
    """현재 인증된 관리자 정보를 반환한다.

    HttpOnly 쿠키 → Bearer 헤더 순으로 JWT를 읽는다.

    Args:
        request: FastAPI Request (쿠키 접근용).
        credentials: HTTP Bearer 인증 정보 (폴백).

    Returns:
        JWT 클레임 딕셔너리 (sub, email, role 등).

    Raises:
        HTTPException: 인증 실패 시 401.
    """
    # 1) HttpOnly 쿠키에서 토큰 읽기
    token = request.cookies.get("portfiq_admin_token")
    # 2) 없으면 Authorization 헤더 폴백
    if not token and credentials is not None:
        token = credentials.credentials
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )
    payload = _decode_token(token)
    return payload


def require_roles(*allowed_roles: str):
    """특정 역할만 접근 가능하도록 제한하는 의존성 팩토리.

    Args:
        *allowed_roles: 허용할 역할 목록 (예: "ceo", "cto").

    Returns:
        FastAPI 의존성 함수.

    Example:
        @router.post("/deploy", dependencies=[Depends(require_roles("ceo", "cto"))])
    """

    async def _check_role(
        admin: dict[str, Any] = Depends(get_current_admin),
    ) -> dict[str, Any]:
        """역할을 검증한다.

        Args:
            admin: 현재 인증된 관리자 클레임.

        Returns:
            검증 통과 시 관리자 클레임.

        Raises:
            HTTPException: 역할이 허용 목록에 없으면 403.
        """
        role = admin.get("role", "")
        if role not in allowed_roles:
            roles_str = " or ".join(allowed_roles)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Insufficient permissions. Required role: {roles_str}",
            )
        return admin

    return _check_role
