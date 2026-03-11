"""Admin API 라우터 — 대시보드, 퍼널, 리텐션, 유저, 이벤트, 푸시, 배포.

모든 엔드포인트는 JWT Bearer 인증이 필요하며,
배포 관련 엔드포인트는 ceo/cto 역할만 접근 가능하다.
"""

from __future__ import annotations

import logging
from datetime import date, timedelta
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from pydantic import BaseModel, Field

from config import settings
from middleware.admin_auth import get_current_admin, require_roles
from middleware.rate_limit import limiter, RATE_LOGIN, RATE_DEPLOY, RATE_PUSH_SEND
from services import admin_service

logger = logging.getLogger(__name__)

router = APIRouter()


# ──────────────────────────────────────────────
# Request / Response Schemas
# ──────────────────────────────────────────────

class PushSendRequest(BaseModel):
    """푸시 발송 요청 스키마."""

    target: str = Field(
        ...,
        description="발송 대상. 'all'이면 전체, 아니면 특정 device_id.",
    )
    title: str = Field(..., description="푸시 제목.")
    body: str = Field(..., description="푸시 본문.")


class TestPushRequest(BaseModel):
    """테스트 푸시 발송 요청 스키마."""

    device_token: str = Field(..., description="FCM 디바이스 토큰.")
    title: str = Field(default="테스트", description="푸시 제목.")
    body: str = Field(default="푸시 테스트입니다", description="푸시 본문.")


class AdminLoginRequest(BaseModel):
    """관리자 로그인 요청 스키마."""

    email: str = Field(..., description="관리자 이메일.")
    password: str = Field(..., description="비밀번호.")


class DeployApproveRequest(BaseModel):
    """배포 승인 요청 스키마."""

    release_id: str = Field(..., description="릴리즈 ID.")
    totp_code: str = Field(..., description="TOTP 6자리 코드.")


class DeployExecuteRequest(BaseModel):
    """배포 실행 요청 스키마."""

    release_id: str = Field(..., description="릴리즈 ID.")
    target_environment: str = Field(
        ...,
        description="배포 대상 환경. 'staging' 또는 'production'.",
    )
    totp_code: str = Field(..., description="TOTP 6자리 코드.")


# ──────────────────────────────────────────────
# 0. Trigger News Collection (수동 트리거)
# ──────────────────────────────────────────────

@router.post("/trigger-collection")
async def trigger_collection(
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """뉴스 수집을 수동으로 트리거한다.

    RSS 피드에서 뉴스를 수집하고, 영향 분류 및 번역을 수행한 뒤
    Supabase에 저장하고 인메모리 캐시를 갱신한다.

    Returns:
        수집 결과 (상태, 수집 건수).
    """
    from jobs.news_collector import collect_news

    try:
        count = await collect_news()
        logger.info(
            "수동 뉴스 수집 완료: admin=%s, count=%d",
            admin.get("email", "unknown"),
            count,
        )
        return {"status": "ok", "collected": count}
    except Exception as e:
        logger.error("수동 뉴스 수집 실패: %s", e)
        return {"status": "error", "detail": str(e)}


# ──────────────────────────────────────────────
# 1. Dashboard KPI
# ──────────────────────────────────────────────

@router.get("/dashboard")
async def get_dashboard(
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """대시보드 KPI 통계를 반환한다.

    DAU, D7 리텐션, 신규 설치, 온보딩 전환율,
    브리핑 생성 수, 푸시 오픈율 등을 전일 대비 변화율과 함께 제공한다.

    Returns:
        KPI 데이터 딕셔너리.
    """
    try:
        return await admin_service.get_dashboard_stats()
    except Exception as e:
        logger.error("대시보드 메트릭 계산 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to compute dashboard metrics",
        )


# ──────────────────────────────────────────────
# 2. Funnel Analysis
# ──────────────────────────────────────────────

@router.get("/funnel")
async def get_funnel(
    start_date: date | None = Query(None, description="시작일 (YYYY-MM-DD)"),
    end_date: date | None = Query(None, description="종료일 (YYYY-MM-DD)"),
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """7단계 온보딩 퍼널 분석 데이터를 반환한다.

    Args:
        start_date: 분석 시작일 (기본: 7일 전).
        end_date: 분석 종료일 (기본: 오늘).

    Returns:
        퍼널 단계별 카운트, 비율, 이탈률 데이터.
    """
    if start_date is None:
        start_date = date.today() - timedelta(days=7)
    if end_date is None:
        end_date = date.today()

    if start_date > end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date must be before end_date",
        )

    try:
        return await admin_service.get_funnel_data(start_date, end_date)
    except Exception as e:
        logger.error("퍼널 분석 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to compute funnel data",
        )


# ──────────────────────────────────────────────
# 3. Cohort Retention
# ──────────────────────────────────────────────

@router.get("/retention")
async def get_retention(
    weeks: int = Query(8, ge=1, le=12, description="코호트 주 수 (1-12)"),
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """주간 코호트 리텐션 매트릭스를 반환한다.

    Args:
        weeks: 반환할 코호트 주 수 (기본: 8, 최대: 12).

    Returns:
        코호트별 리텐션 히트맵 데이터.
    """
    try:
        return await admin_service.get_retention_data(weeks)
    except Exception as e:
        logger.error("리텐션 분석 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to compute retention data",
        )


# ──────────────────────────────────────────────
# 4. User Statistics
# ──────────────────────────────────────────────

@router.get("/users/stats")
async def get_user_statistics(
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """유저 통계를 반환한다.

    총 설치 수, 활성 사용자 (7일/30일), 푸시 허용 비율,
    플랫폼 분포, 인기 ETF 등.

    Returns:
        유저 통계 딕셔너리.
    """
    try:
        return await admin_service.get_user_stats()
    except Exception as e:
        logger.error("유저 통계 조회 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to compute user statistics",
        )


# ──────────────────────────────────────────────
# 5. User List (Paginated)
# ──────────────────────────────────────────────

@router.get("/users")
async def list_users(
    page: int = Query(1, ge=1, description="페이지 번호"),
    size: int = Query(20, ge=1, le=100, description="페이지당 항목 수"),
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """유저 목록을 페이지네이션으로 반환한다.

    Args:
        page: 페이지 번호 (1-based).
        size: 페이지당 항목 수 (기본: 20, 최대: 100).

    Returns:
        유저 목록과 페이지네이션 메타데이터.
    """
    try:
        return await admin_service.get_users(page, size)
    except Exception as e:
        logger.error("유저 목록 조회 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch user list",
        )


# ──────────────────────────────────────────────
# 6. Event Explorer
# ──────────────────────────────────────────────

@router.get("/events")
async def get_events(
    event_name: str | None = Query(None, description="이벤트명 필터"),
    device_id: str | None = Query(None, description="디바이스 ID 필터"),
    start_date: date | None = Query(None, description="시작일 (YYYY-MM-DD)"),
    end_date: date | None = Query(None, description="종료일 (YYYY-MM-DD)"),
    limit: int = Query(100, ge=1, le=500, description="결과 수 (1-500)"),
    offset: int = Query(0, ge=0, description="오프셋"),
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """이벤트 로그를 필터링하여 반환한다.

    Args:
        event_name: 이벤트명 정확 일치 필터.
        device_id: 디바이스 ID 정확 일치 필터.
        start_date: 시작일 (기본: 24시간 전).
        end_date: 종료일 (기본: 오늘).
        limit: 페이지 크기 (1-500).
        offset: 페이지네이션 오프셋.

    Returns:
        이벤트 목록과 페이지네이션 메타데이터.
    """
    try:
        return await admin_service.get_events(
            limit=limit,
            offset=offset,
            event_name=event_name,
            device_id=device_id,
            start_date=start_date,
            end_date=end_date,
        )
    except Exception as e:
        logger.error("이벤트 탐색 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch events",
        )


# ──────────────────────────────────────────────
# 7. Push Send
# ──────────────────────────────────────────────

@router.post("/push/send")
@limiter.limit(RATE_PUSH_SEND)
async def send_push(
    request: Request,
    body: PushSendRequest,
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """관리자 푸시 알림을 발송한다.

    Args:
        request: 발송 대상, 제목, 본문.

    Returns:
        발송 결과 요약 (total, success, failed).
    """
    try:
        result = await admin_service.send_admin_push(
            target=body.target,
            title=body.title,
            body=body.body,
        )
        logger.info(
            "관리자 푸시 발송: target=%s, admin=%s, result=%s",
            body.target,
            admin.get("email", "unknown"),
            result,
        )
        return result
    except Exception as e:
        logger.error("푸시 발송 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send push notification",
        )


# ──────────────────────────────────────────────
# 7.5. Test Push (디버깅 / QA용)
# ──────────────────────────────────────────────

@router.post("/test-push")
async def test_push(
    body: TestPushRequest,
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """테스트 푸시 알림을 특정 디바이스 토큰으로 발송한다.

    Firebase 초기화 상태와 토큰 유효성을 빠르게 검증하기 위한 엔드포인트.
    Admin 인증이 필요하다.

    Args:
        body: 디바이스 토큰, 제목, 본문.

    Returns:
        발송 성공 여부와 상세 정보.
    """
    from services.push_service import send_push_to_token, _firebase_initialized, _firebase_app

    try:
        success = await send_push_to_token(
            token=body.device_token,
            title=body.title,
            body=body.body,
            data={"type": "test"},
        )

        return {
            "success": success,
            "firebase_initialized": _firebase_initialized,
            "firebase_active": _firebase_app is not None,
            "device_token": f"{body.device_token[:20]}..." if len(body.device_token) > 20 else body.device_token,
            "title": body.title,
            "body": body.body,
            "message": "푸시 발송 성공" if success else "푸시 발송 실패",
        }
    except Exception as e:
        logger.error("테스트 푸시 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"테스트 푸시 발송 실패: {e}",
        )


# ──────────────────────────────────────────────
# 8. Deploy Status
# ──────────────────────────────────────────────

@router.get("/deploy/status/{run_id}")
async def get_deploy_status(
    run_id: str,
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """배포 상태를 조회한다.

    Args:
        run_id: GitHub Actions run ID.

    Returns:
        배포 상태 딕셔너리 (status, steps, duration 등).
    """
    try:
        result = await admin_service.get_deploy_status(run_id)
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Deployment run not found: {run_id}",
            )
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error("배포 상태 조회 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch deploy status",
        )


# ──────────────────────────────────────────────
# 9. Deploy Approval (ceo/cto only)
# ──────────────────────────────────────────────

@router.post("/deploy/approve")
@limiter.limit(RATE_DEPLOY)
async def approve_deploy(
    request: Request,
    body: DeployApproveRequest,
    admin: dict[str, Any] = Depends(require_roles("ceo", "cto")),
) -> dict[str, Any]:
    """배포를 승인한다. CEO와 CTO 이중 승인이 필요하다.

    Args:
        request: FastAPI Request (rate limiter용).
        body: 릴리즈 ID와 TOTP 코드.

    Returns:
        승인 결과 딕셔너리.
    """
    sb = None
    try:
        from services.supabase_client import get_supabase
        sb = get_supabase()
    except Exception as e:
        logger.error("Supabase 연결 실패: %s", e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection failed",
        )

    role = admin.get("role", "")
    email = admin.get("email", "")

    # 릴리즈 존재 확인
    release_resp = (
        sb.table("deploy_releases")
        .select("*")
        .eq("release_id", body.release_id)
        .limit(1)
        .execute()
    )
    if not release_resp.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Release not found: {body.release_id}",
        )

    release = release_resp.data[0]
    if release.get("status") not in ("pending", "approved"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Release is already {release.get('status', 'unknown')}",
        )

    # 이미 승인했는지 확인
    existing_resp = (
        sb.table("deploy_approvals")
        .select("*")
        .eq("release_id", body.release_id)
        .eq("role", role)
        .execute()
    )
    if existing_resp.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Release already approved by {role}",
        )

    # TOTP 검증
    try:
        import pyotp

        admin_user_resp = (
            sb.table("admin_users")
            .select("totp_secret")
            .eq("email", email)
            .limit(1)
            .execute()
        )
        if not admin_user_resp.data or not admin_user_resp.data[0].get("totp_secret"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="TOTP not configured for this admin user",
            )
        totp_secret = admin_user_resp.data[0]["totp_secret"]
        totp = pyotp.TOTP(totp_secret)
        if not totp.verify(body.totp_code):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid TOTP code",
            )
    except ImportError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server TOTP module (pyotp) is not installed",
        )
    except HTTPException:
        raise

    # 승인 기록
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).isoformat()

    sb.table("deploy_approvals").insert({
        "release_id": body.release_id,
        "role": role,
        "approved_by": email,
        "totp_verified": True,
        "approved_at": now,
    }).execute()

    # 전체 승인 상태 확인
    all_approvals_resp = (
        sb.table("deploy_approvals")
        .select("*")
        .eq("release_id", body.release_id)
        .execute()
    )
    approvals = all_approvals_resp.data or []
    approved_roles = {a["role"] for a in approvals}
    approvals_complete = "ceo" in approved_roles and "cto" in approved_roles

    if approvals_complete:
        sb.table("deploy_releases").update(
            {"status": "approved"}
        ).eq("release_id", body.release_id).execute()

    # 응답 구성
    approval_list = []
    for r in ("ceo", "cto"):
        match = next((a for a in approvals if a["role"] == r), None)
        approval_list.append({
            "role": r,
            "approved": match is not None,
            "approved_at": match["approved_at"] if match else None,
        })

    missing = [r for r in ("ceo", "cto") if r not in approved_roles]
    if approvals_complete:
        message = "All approvals complete. Ready for deployment."
    else:
        message = f"Approval recorded. Waiting for {', '.join(missing)} approval."

    return {
        "release_id": body.release_id,
        "approved_by": email,
        "role": role,
        "totp_verified": True,
        "approved_at": now,
        "approvals_complete": approvals_complete,
        "approvals": approval_list,
        "message": message,
    }


# ──────────────────────────────────────────────
# 10. Deploy Execute (ceo/cto only)
# ──────────────────────────────────────────────

@router.post("/deploy/execute")
@limiter.limit(RATE_DEPLOY)
async def execute_deploy(
    request: Request,
    body: DeployExecuteRequest,
    admin: dict[str, Any] = Depends(require_roles("ceo", "cto")),
) -> dict[str, Any]:
    """배포를 실행한다. 이중 승인 완료 후에만 가능하다.

    Args:
        request: FastAPI Request (rate limiter용).
        body: 릴리즈 ID, 대상 환경, TOTP 코드.

    Returns:
        GitHub Actions run ID와 배포 상태.
    """
    if body.target_environment not in ("staging", "production"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="target_environment must be 'staging' or 'production'",
        )

    from services.supabase_client import get_supabase
    sb = get_supabase()
    email = admin.get("email", "")

    # 릴리즈 확인
    release_resp = (
        sb.table("deploy_releases")
        .select("*")
        .eq("release_id", body.release_id)
        .limit(1)
        .execute()
    )
    if not release_resp.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Release not found: {body.release_id}",
        )

    release = release_resp.data[0]
    if release.get("status") in ("deploying", "deployed"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Release is already deploying or deployed",
        )

    # 이중 승인 확인
    approvals_resp = (
        sb.table("deploy_approvals")
        .select("role")
        .eq("release_id", body.release_id)
        .execute()
    )
    approved_roles = {a["role"] for a in (approvals_resp.data or [])}
    missing = [r for r in ("ceo", "cto") if r not in approved_roles]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Dual approval required. Missing approval from: {', '.join(missing)}",
        )

    # TOTP 재검증
    try:
        import pyotp

        admin_user_resp = (
            sb.table("admin_users")
            .select("totp_secret")
            .eq("email", email)
            .limit(1)
            .execute()
        )
        if admin_user_resp.data and admin_user_resp.data[0].get("totp_secret"):
            totp = pyotp.TOTP(admin_user_resp.data[0]["totp_secret"])
            if not totp.verify(body.totp_code):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid TOTP code",
                )
    except ImportError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server TOTP module (pyotp) is not installed",
        )
    except HTTPException:
        raise

    # GitHub Actions 워크플로우 트리거
    import os
    from datetime import datetime, timezone

    github_token = os.getenv("GITHUB_TOKEN", "")
    github_repo = os.getenv("GITHUB_REPO", "")
    workflow_id = os.getenv("GITHUB_WORKFLOW_ID", "deploy.yml")

    github_run_id = ""
    now = datetime.now(timezone.utc).isoformat()

    if github_token and github_repo:
        try:
            import subprocess

            result = subprocess.run(
                [
                    "gh", "api",
                    f"repos/{github_repo}/actions/workflows/{workflow_id}/dispatches",
                    "-f", "ref=main",
                    "-f", f"inputs[environment]={body.target_environment}",
                    "-f", f"inputs[release_id]={body.release_id}",
                ],
                capture_output=True,
                text=True,
                timeout=30,
                env={**os.environ, "GH_TOKEN": github_token},
            )
            if result.returncode != 0:
                logger.error("GitHub Actions 트리거 실패: %s", result.stderr)
            else:
                # 최신 run ID 조회
                runs_result = subprocess.run(
                    [
                        "gh", "api",
                        f"repos/{github_repo}/actions/runs",
                        "--jq", ".workflow_runs[0].id",
                    ],
                    capture_output=True,
                    text=True,
                    timeout=15,
                    env={**os.environ, "GH_TOKEN": github_token},
                )
                github_run_id = runs_result.stdout.strip()
        except Exception as e:
            logger.error("GitHub Actions 트리거 예외: %s", e)
    else:
        logger.warning("GITHUB_TOKEN/GITHUB_REPO 미설정 — 배포 트리거 건너뜀")
        github_run_id = "dry-run"

    # deploy_history 기록
    sb.table("deploy_history").insert({
        "release_id": body.release_id,
        "github_run_id": github_run_id,
        "status": "deploying",
        "triggered_by": email,
        "target_environment": body.target_environment,
        "started_at": now,
    }).execute()

    # 릴리즈 상태 업데이트
    sb.table("deploy_releases").update(
        {"status": "deploying"}
    ).eq("release_id", body.release_id).execute()

    return {
        "release_id": body.release_id,
        "github_run_id": github_run_id,
        "status": "deploying",
        "triggered_by": email,
        "started_at": now,
        "message": f"Deployment triggered. Monitor at /api/v1/admin/deploy/status/{github_run_id}",
    }


# ──────────────────────────────────────────────
# 11. Admin Login
# ──────────────────────────────────────────────

@router.post("/auth/login")
@limiter.limit(RATE_LOGIN)
async def admin_login(
    request: Request,
    body: AdminLoginRequest,
    response: Response,
) -> dict[str, Any]:
    """관리자 로그인. JWT 토큰을 HttpOnly 쿠키로 발급한다.

    Args:
        request: FastAPI Request (rate limiter용).
        body: 이메일과 비밀번호.
        response: FastAPI Response (쿠키 설정용).

    Returns:
        token_type, expires_in, user 정보. JWT는 HttpOnly 쿠키로 전달.
    """
    import os
    from datetime import datetime, timezone

    import jwt as pyjwt

    from services.supabase_client import get_supabase
    sb = get_supabase()

    # 사용자 조회
    user_resp = (
        sb.table("admin_users")
        .select("*")
        .eq("email", body.email)
        .limit(1)
        .execute()
    )
    if not user_resp.data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    user = user_resp.data[0]

    # 비밀번호 검증
    try:
        import bcrypt

        stored_hash = user.get("password_hash", "")
        if isinstance(stored_hash, str):
            stored_hash = stored_hash.encode("utf-8")
        password_bytes = body.password.encode("utf-8")

        if not bcrypt.checkpw(password_bytes, stored_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )
    except ImportError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server authentication module (bcrypt) is not installed",
        )
    except HTTPException:
        raise

    # JWT 생성
    secret = os.getenv("ADMIN_JWT_SECRET", "")
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Admin authentication is not configured",
        )

    now = datetime.now(timezone.utc)
    expires_in = 3600  # 1시간
    payload = {
        "sub": str(user.get("id", "")),
        "email": user["email"],
        "role": user.get("role", "pm"),
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=expires_in)).timestamp()),
    }

    access_token = pyjwt.encode(payload, secret, algorithm="HS256")

    # HttpOnly 쿠키로 JWT 설정
    is_prod = settings.ENVIRONMENT == "production"
    response.set_cookie(
        key="portfiq_admin_token",
        value=access_token,
        httponly=True,
        secure=is_prod,
        samesite="lax",
        max_age=expires_in,
        path="/",
    )

    return {
        "token_type": "bearer",
        "expires_in": expires_in,
        "user": {
            "id": user.get("id"),
            "email": user["email"],
            "role": user.get("role", "pm"),
        },
    }


# ──────────────────────────────────────────────
# 12. Admin Logout
# ──────────────────────────────────────────────

@router.post("/auth/logout")
async def admin_logout(response: Response) -> dict[str, str]:
    """로그아웃. HttpOnly 쿠키를 삭제한다.

    Returns:
        로그아웃 성공 메시지.
    """
    response.delete_cookie(
        key="portfiq_admin_token",
        path="/",
    )
    return {"message": "Logged out successfully"}


# ──────────────────────────────────────────────
# 13. Cache Management
# ──────────────────────────────────────────────

@router.post("/cache/clear")
async def clear_cache(
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """인메모리 캐시를 전체 클리어한다.

    popular ETF, 브리핑, 뉴스 피드, ETF 분석 등의 캐시를 초기화한다.
    다음 요청 시 최신 데이터로 재생성된다.

    Returns:
        클리어된 캐시 항목 수와 결과 메시지.
    """
    from services.cache import clear_cache as do_clear_cache

    cleared = do_clear_cache()
    logger.info(
        "Cache cleared by admin %s: %d entries",
        admin.get("email", "unknown"),
        cleared,
    )
    return {
        "cleared": cleared,
        "message": f"캐시 {cleared}개 항목 초기화 완료",
    }


@router.get("/cache/stats")
async def cache_stats(
    admin: dict[str, Any] = Depends(get_current_admin),
) -> dict[str, Any]:
    """현재 캐시 상태를 반환한다.

    Returns:
        캐시 크기, TTL, 저장된 키 목록.
    """
    from services.cache import get_cache_stats

    return get_cache_stats()
