# Portfiq v1.0.0 릴리즈 QA 리포트

> 최종 갱신: 2026-03-13
> 작성자: QA-Release Agent

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
| `GET /api/v1/etf/detail/QQQ` | **PASS** |
| `GET /api/v1/etf/trending` | **PASS** |
| `POST /api/v1/etf/register` | **PASS** |
| `GET /api/v1/holdings/QQQ` | **PASS** |
| `GET /api/v1/calendar` | **PASS** |
| `GET /api/v1/analytics/events` | **PASS** |
| `GET /api/v1/admin/stats` | **PASS** |
| `GET /api/v1/devices/preferences` | **PASS** |

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
