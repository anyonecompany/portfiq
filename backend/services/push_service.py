"""FCM 푸시 알림 서비스 — Firebase Admin SDK 연동.

Firebase 서비스 계정이 설정되면 실제 FCM 전송을 수행하고,
설정되지 않으면 로깅만 수행 (앱 크래시 없음).
"""

from __future__ import annotations

import json
import logging
from typing import Any

logger = logging.getLogger(__name__)

# In-memory token store (Supabase 전환 전 fallback)
_push_tokens: dict[str, str] = {}  # device_id -> push_token

# Firebase 초기화 상태
_firebase_initialized: bool = False
_firebase_app: Any = None


def _init_firebase() -> bool:
    """Firebase Admin SDK를 lazy 초기화한다.

    GOOGLE_APPLICATION_CREDENTIALS 환경변수 또는
    FIREBASE_SERVICE_ACCOUNT_JSON 환경변수로 서비스 계정 인증.

    Returns:
        초기화 성공 여부.
    """
    global _firebase_initialized, _firebase_app

    if _firebase_initialized:
        return _firebase_app is not None

    _firebase_initialized = True

    try:
        import firebase_admin
        from firebase_admin import credentials

        # 이미 초기화된 경우
        try:
            _firebase_app = firebase_admin.get_app()
            logger.info("Firebase Admin SDK 이미 초기화됨")
            return True
        except ValueError:
            pass

        from config import settings

        # 방법 1: FIREBASE_SERVICE_ACCOUNT_JSON (JSON 문자열)
        service_account_json = settings.FIREBASE_SERVICE_ACCOUNT_JSON
        if service_account_json:
            try:
                cred_dict = json.loads(service_account_json)
                cred = credentials.Certificate(cred_dict)
                _firebase_app = firebase_admin.initialize_app(cred)
                logger.info("Firebase Admin SDK 초기화 완료 (JSON env)")
                return True
            except (json.JSONDecodeError, Exception) as e:
                logger.error("Firebase 서비스 계정 JSON 파싱 실패: %s", e)

        # 방법 2: FIREBASE_CREDENTIALS_PATH (파일 경로, 명시적 설정)
        firebase_creds_path = settings.FIREBASE_CREDENTIALS_PATH
        if firebase_creds_path:
            try:
                cred = credentials.Certificate(firebase_creds_path)
                _firebase_app = firebase_admin.initialize_app(cred)
                logger.info("Firebase Admin SDK 초기화 완료 (파일: %s)", firebase_creds_path)
                return True
            except Exception as e:
                logger.error("Firebase 서비스 계정 파일 로드 실패 (FIREBASE_CREDENTIALS_PATH): %s", e)

        # 방법 3: GOOGLE_APPLICATION_CREDENTIALS (파일 경로, 환경변수로 자동 감지)
        google_creds_path = settings.GOOGLE_APPLICATION_CREDENTIALS
        if google_creds_path:
            try:
                cred = credentials.Certificate(google_creds_path)
                _firebase_app = firebase_admin.initialize_app(cred)
                logger.info("Firebase Admin SDK 초기화 완료 (파일: %s)", google_creds_path)
                return True
            except Exception as e:
                logger.error("Firebase 서비스 계정 파일 로드 실패 (GOOGLE_APPLICATION_CREDENTIALS): %s", e)

        # 방법 4: Application Default Credentials (GCP 환경)
        try:
            _firebase_app = firebase_admin.initialize_app()
            logger.info("Firebase Admin SDK 초기화 완료 (ADC)")
            return True
        except Exception:
            pass

        logger.warning(
            "Firebase 미설정 — FIREBASE_SERVICE_ACCOUNT_JSON 또는 "
            "GOOGLE_APPLICATION_CREDENTIALS 환경변수를 설정하세요. "
            "푸시 알림은 로그만 남깁니다."
        )
        return False

    except ImportError:
        logger.warning("firebase-admin 패키지 미설치 — pip install firebase-admin")
        return False


def init_firebase() -> bool:
    """Firebase Admin SDK를 명시적으로 초기화한다.

    서버 시작 시 호출하여 Firebase 연결 상태를 미리 확인한다.
    초기화 실패해도 예외를 발생시키지 않으며 False를 반환한다.

    Returns:
        초기화 성공 여부.
    """
    result = _init_firebase()
    if result:
        logger.info("Firebase 초기화 성공 — FCM 푸시 활성")
    else:
        logger.warning("Firebase 초기화 실패 — 푸시 알림은 로그만 남깁니다")
    return result


async def send_push_to_token(
    token: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> bool:
    """푸시 토큰을 직접 지정하여 알림을 전송한다.

    테스트 푸시 등 device_id 없이 토큰만으로 발송할 때 사용한다.

    Args:
        token: FCM 푸시 토큰.
        title: 알림 제목.
        body: 알림 본문.
        data: 추가 데이터 페이로드.

    Returns:
        전송 성공 여부.
    """
    if not token:
        logger.warning("푸시 토큰이 비어있음")
        return False

    if not _init_firebase():
        logger.info(
            "테스트 푸시 (Firebase 미설정, 로그만): token=%s..., title='%s'",
            token[:20], title,
        )
        return True

    try:
        from firebase_admin import messaging

        str_data = {k: str(v) for k, v in (data or {}).items()}

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=token,
            data=str_data,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="portfiq_briefing",
                    priority="high",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        sound="default",
                        badge=1,
                    ),
                ),
            ),
        )

        response = messaging.send(message)
        logger.info("테스트 FCM 전송 성공: token=%s..., response=%s", token[:20], response)
        return True

    except Exception as e:
        logger.error("테스트 FCM 전송 실패: token=%s..., error=%s", token[:20], e)
        return False


def register_token(device_id: str, push_token: str) -> bool:
    """푸시 토큰을 등록한다.

    Args:
        device_id: 디바이스 ID.
        push_token: FCM 푸시 토큰.

    Returns:
        등록 성공 여부.
    """
    try:
        from services.supabase_client import get_supabase
        sb = get_supabase()
        sb.table("devices").upsert({
            "device_id": device_id,
            "push_token": push_token,
        }, on_conflict="device_id").execute()
        logger.info("푸시 토큰 등록: %s", device_id)
        return True
    except Exception as e:
        logger.warning("Supabase 토큰 저장 실패, 인메모리 저장: %s", e)
        _push_tokens[device_id] = push_token
        return True


def _get_push_token(device_id: str) -> str | None:
    """디바이스 ID로 푸시 토큰을 조회한다.

    Args:
        device_id: 디바이스 ID.

    Returns:
        푸시 토큰 문자열, 없으면 None.
    """
    try:
        from services.supabase_client import get_supabase
        sb = get_supabase()
        resp = (
            sb.table("devices")
            .select("push_token")
            .eq("device_id", device_id)
            .execute()
        )
        rows: list[dict] = resp.data  # type: ignore[assignment]
        if rows and rows[0].get("push_token"):
            return str(rows[0]["push_token"])
    except Exception as e:
        logger.warning("Supabase 토큰 조회 실패, 인메모리 조회: %s", e)

    return _push_tokens.get(device_id)


def _get_all_device_tokens() -> list[dict[str, str]]:
    """모든 디바이스의 device_id + push_token 목록을 조회한다.

    Returns:
        [{"device_id": "...", "push_token": "..."}, ...] 형태의 리스트.
    """
    results: list[dict[str, str]] = []

    try:
        from services.supabase_client import get_supabase
        sb = get_supabase()
        resp = (
            sb.table("devices")
            .select("device_id, push_token")
            .neq("push_token", "")
            .execute()
        )
        rows_all: list[dict] = resp.data  # type: ignore[assignment]
        if rows_all:
            results = [
                {"device_id": str(row["device_id"]), "push_token": str(row["push_token"])}
                for row in rows_all
                if row.get("push_token")
            ]
            return results
    except Exception as e:
        logger.warning("Supabase 전체 토큰 조회 실패, 인메모리 fallback: %s", e)

    # Fallback: 인메모리 토큰
    for device_id, token in _push_tokens.items():
        if token:
            results.append({"device_id": device_id, "push_token": token})
    return results


def _remove_invalid_token(device_id: str) -> None:
    """유효하지 않은 토큰을 DB에서 제거한다.

    Args:
        device_id: 토큰을 제거할 디바이스 ID.
    """
    try:
        from services.supabase_client import get_supabase
        sb = get_supabase()
        sb.table("devices").update({"push_token": ""}).eq("device_id", device_id).execute()
        logger.info("만료/무효 토큰 제거: %s", device_id)
    except Exception as e:
        logger.warning("Supabase 토큰 제거 실패: %s", e)

    _push_tokens.pop(device_id, None)


async def send_push(
    device_id: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> bool:
    """푸시 알림을 전송한다.

    Firebase가 설정되어 있으면 실제 FCM 전송, 아니면 로깅만 수행.

    Args:
        device_id: 대상 디바이스 ID.
        title: 알림 제목.
        body: 알림 본문.
        data: 추가 데이터 페이로드.

    Returns:
        전송 성공 여부.
    """
    push_token = _get_push_token(device_id)
    if not push_token:
        logger.warning("푸시 토큰 없음: device=%s", device_id)
        return False

    if not _init_firebase():
        logger.info(
            "푸시 알림 (Firebase 미설정, 로그만): device=%s, title='%s', body='%s'",
            device_id, title, body,
        )
        return True

    try:
        from firebase_admin import messaging

        # data 값은 모두 문자열이어야 함
        str_data = {k: str(v) for k, v in (data or {}).items()}

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=push_token,
            data=str_data,
            # Android 알림 채널 설정
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="portfiq_briefing",
                    priority="high",
                ),
            ),
            # iOS APNs 설정
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        sound="default",
                        badge=1,
                    ),
                ),
            ),
        )

        response = messaging.send(message)
        logger.info("FCM 전송 성공: device=%s, response=%s", device_id, response)
        return True

    except Exception as e:
        error_str = str(e)

        # 만료되거나 유효하지 않은 토큰 처리
        if any(keyword in error_str.lower() for keyword in [
            "not-registered", "invalid-registration", "invalid-argument",
            "registration-token-not-registered", "sender-id-mismatch",
        ]):
            logger.warning("무효/만료 토큰 감지, 제거: device=%s, error=%s", device_id, e)
            _remove_invalid_token(device_id)
        else:
            logger.error("FCM 전송 실패: device=%s, error=%s", device_id, e)

        return False


async def send_briefing_push(
    device_id: str,
    briefing_type: str,
    title: str,
    body: str = "",
) -> bool:
    """브리핑 생성 후 푸시 알림을 전송한다.

    Args:
        device_id: 대상 디바이스 ID.
        briefing_type: "morning" 또는 "night".
        title: 브리핑 제목.
        body: 알림 본문 (빈 문자열이면 기본 메시지 생성).

    Returns:
        전송 성공 여부.
    """
    emoji = "\U0001f305" if briefing_type == "morning" else "\U0001f319"
    if not body:
        body = f"{emoji} {title}"

    return await send_push(
        device_id,
        "Portfiq",
        body,
        {"type": "briefing", "briefing_type": briefing_type},
    )


async def send_bulk_briefing_push(
    briefing_type: str,
    title: str,
    body: str = "",
) -> dict[str, Any]:
    """모든 등록된 디바이스에 브리핑 푸시를 전송한다.

    Args:
        briefing_type: "morning" 또는 "night".
        title: 브리핑 제목.
        body: 알림 본문.

    Returns:
        전송 결과 요약 {"total": int, "success": int, "failed": int}.
    """
    devices = _get_all_device_tokens()
    total = len(devices)
    success = 0
    failed = 0

    for device in devices:
        try:
            result = await send_briefing_push(
                device_id=device["device_id"],
                briefing_type=briefing_type,
                title=title,
                body=body,
            )
            if result:
                success += 1
            else:
                failed += 1
        except Exception as e:
            logger.error(
                "벌크 푸시 실패: device=%s, error=%s",
                device["device_id"], e,
            )
            failed += 1

    logger.info(
        "벌크 브리핑 푸시 완료: type=%s, total=%d, success=%d, failed=%d",
        briefing_type, total, success, failed,
    )
    return {"total": total, "success": success, "failed": failed}
