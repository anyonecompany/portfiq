# Portfiq 출시 판정 보고

> 일시: 2026-03-22 | 판정: **Go — 출시 가능**

## 수정 8건

| # | 심각도 | 내용 |
|---|--------|------|
| 1 | P0 | Android APK 빌드 차단 해소 (`flutter_native_splash` dev→dep 이동) |
| 2 | P1 | ETF 삭제 서버 동기화 (DELETE `/api/v1/etf/unregister` 신설 + Flutter 연동) |
| 3 | P1 | mock/fallback 뉴스에 "샘플 데이터" 배너 추가 (`isMock` 필드 도입) |
| 4 | P1 | 푸시 권한 거부 시 `onDenied()` 정상 호출 (기존: 항상 granted 처리) |
| 5 | P1 | 알림 시간 TimePicker 제거 → 서버 고정 시간 표시 (거짓 UX 제거) |
| 6 | P1 | 온보딩 ETF 검색: 하드코딩 24개 → API 실시간 검색 + 300ms debounce |
| 7 | P1 | 온보딩 피드 로드 실패 시 에러 화면 + 재시도 버튼 |
| 8 | P1 | 피드 새로고침 시 기존 콘텐츠 유지 (화면 blank 제거) |

## 검증 결과

| 항목 | 결과 |
|------|------|
| `flutter analyze` | 0 issues |
| `flutter test` | 1/1 PASS |
| `flutter build apk --target lib/main_production.dart` | SUCCESS (57.5MB) |
| `admin npm run build` | SUCCESS (10 routes) |

## 잔여 리스크

- 로컬 pytest 환경 아키텍처 불일치 (arm64/x86_64) — Fly.io 배포 환경에서는 무관
- 알림 시간 개인화 미지원 — UI를 서버 고정 시간으로 정직하게 변경 완료
- CupertinoIcons font 미포함 경고 — 실제 미사용 시 무영향
