# Portfiq v1.0.0 릴리즈 QA 리포트

> 최종 갱신: 2026-03-13
> 작성자: QA-Release Agent

## 2026-03-14 Verification Note

- 앱/백엔드/어드민 간 analytics 이벤트 계약을 재정렬함 (`app_opened`, `session_started`, `push_received`, `push_tapped` 기준).
- 어드민 대시보드 KPI/퍼널/푸시 응답 계약을 현재 코드 기준으로 수정함.
- 디바이스 등록 payload에 `platform`, `app_version`을 포함하도록 수정했고, 알림 설정 저장은 Supabase 장애 시 인메모리 fallback을 사용함.
- 마이그레이션 `005_device_preferences_and_deploy_steps.sql` 추가로 `devices` 알림 설정 컬럼과 `deploy_history.steps` 컬럼을 보강함.
- `flutter analyze`, Admin `tsc --noEmit`, Admin `npm run lint`, backend `py_compile`는 2026-03-14 로컬 검증 통과.
- backend 스모크 테스트(`PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest tests/test_release_readiness.py tests/test_health.py tests/test_feed.py`) 2026-03-14 통과.
- 이 문서의 기존 "RELEASE READY" 판정은 최신 E2E 운영 검증을 대체하지 않음. 실제 출시 판정 전에는 프로덕션 Supabase 데이터로 퍼널/리텐션/푸시 지표를 재검증해야 함.

---

## 1. 코드 품질

| 항목 | 결과 | 비고 |
|------|------|------|
| `flutter analyze` | **PASS** | 0 issues |
| Backend `ruff check` | **PASS** | All checks passed |
| Admin `tsc --noEmit` | **PASS** | No errors |

## 2. 릴리즈 빌드

| 플랫폼 | 결과 | 산출물 | 비고 |
|--------|------|--------|------|
| Android AAB | **PASS** | `app-release.aab` (47.9 MB) | NDK strip warning (비차단) |
| iOS Release | **PASS** | `Runner.app` (26.6 MB) | 서명 없이 빌드 성공 |

## 3. 프로덕션 API (Fly.io)

| 엔드포인트 | 결과 |
|-----------|------|
| `GET /health` | **PASS** — `{"status":"ok","version":"1.0.0"}` |
| `GET /api/health` | **PASS** |
| `GET /api/v1/feed` | **PASS** |
| `GET /api/v1/briefing/morning` | **PASS** |
| `GET /api/v1/briefing/night` | **PASS** |
| `POST /api/v1/briefing/generate` | **PASS** (rate limited: 5/hour) |
| `GET /api/v1/etf/search?q=QQQ` | **PASS** |
| `GET /api/v1/etf/QQQ/detail` | **PASS** |
| `GET /api/v1/etf/trending` | **PASS** |
| `POST /api/v1/etf/register` | **PASS** |
| `POST /api/v1/etf/devices/register` | **PASS** |
| `GET /api/v1/etf/QQQ/holdings` | **PASS** |
| `GET /api/v1/calendar` | **PASS** |
| `POST /api/v1/analytics/events` | **PASS** |
| `GET /api/v1/admin/dashboard` | **PASS** |
| `GET /api/v1/devices/{device_id}/preferences` | **PASS** |

## 4. 법적/컴플라이언스

| 항목 | 결과 | 비고 |
|------|------|------|
| 이용약관 | **PASS** | 앱 내 + `docs/terms_of_service.md` |
| 개인정보처리방침 | **PASS** | 앱 내 + `docs/privacy_policy.md` (한/영) |
| AI 서비스 고지 | **PASS** | 설정 화면 AI 고지 섹션 |
| AI 위험 평가 | **PASS** | `docs/ai_risk_assessment.md` v2.0.0 |
| 인공지능기본법 준수 | **PASS** | 고영향 AI 비해당, 고지/라벨링 완료 |
| 투자 면책 조항 | **PASS** | "투자 조언이 아닌 참고 정보" 명시 |

## 5. 보안

| 항목 | 결과 | 비고 |
|------|------|------|
| `.env` gitignore | **PASS** | `.gitignore`에 포함 확인 |
| 하드코딩 API 키 | **PASS** | grep 검색 결과 없음 |
| CORS 설정 | **PASS** | 환경변수 제어 + Vercel regex |
| Rate limiting | **PASS** | slowapi 5/hour on generate |
| Supabase RLS | **PASS** | 활성화 확인 |

## 6. 앱 설정

| 항목 | 값 | 상태 |
|------|-----|------|
| Bundle ID (Android) | `com.portfiq.app` | **OK** |
| Bundle ID (iOS) | `com.portfiq.app` | **OK** |
| 앱 이름 (iOS) | 포트픽 | **OK** |
| 버전 | 1.0.0+1 | **OK** |
| Production API URL | `https://portfiq.fly.dev` | **OK** |
| 앱 아이콘 | 1024x1024 (Dark + Indigo "P") | **OK** |
| 스플래시 스크린 | `#0D0E14` 배경 | **OK** |
| ProGuard | 활성화 (minify + shrink) | **OK** |
| AI 모델 참조 | Google Gemini (Anthropic 제거 완료) | **OK** |

## 7. 출시 문서

| 문서 | 경로 | 상태 |
|------|------|------|
| 스토어 메타데이터 | `docs/store_metadata.md` | **완료** |
| 개인정보처리방침 (한) | `docs/privacy_policy.md` | **완료** |
| 개인정보처리방침 (영) | `docs/privacy_policy_en.md` | **완료** |
| 이용약관 | `docs/terms_of_service.md` | **완료** |
| AI 위험 평가 | `docs/ai_risk_assessment.md` | **완료** |
| 배포 환경변수 가이드 | `docs/deployment_env_vars.md` | **완료** |
| 스크린샷 가이드 | `docs/store_screenshots_guide.md` | **완료** |

## 8. Known Issues (비차단)

- Android NDK `llvm-strip` 미발견 warning — 릴리즈 AAB 생성에 영향 없음
- `cupertino_icons` 폰트 warning — 사용하지 않는 transitive dependency, 기능 영향 없음

## 9. 출시 전 수동 작업

| 작업 | 담당 | 비고 |
|------|------|------|
| Apple Developer 서명 설정 | CTO | Team ID + Bundle ID + 인증서 |
| Android 키스토어 생성 | CTO | `keytool` 수동 생성 필요 |
| TestFlight 업로드 | CTO | Xcode → Archive → Upload |
| Play Console AAB 업로드 | CTO | Play Console → 내부 테스트 |
| DNS CNAME 설정 | CTO | `api.portfiq.com → portfiq.fly.dev` |
| 스크린샷 캡처 | CTO/Designer | 실기기에서 캡처 권장 |

---

## 최종 판정: **RELEASE READY**

모든 자동 검증 항목 PASS. 수동 작업(앱 서명, 스토어 업로드)만 남음.
