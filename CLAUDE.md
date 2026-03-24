# Portfiq (포트픽) — 에이전트 지시서

## 프로젝트 개요

Portfiq는 서학(미국) ETF 투자자를 위한 AI 브리핑 앱이다. Flutter(모바일) + FastAPI(백엔드) + Next.js(어드민 대시보드)로 구성되며, Gemini LLM 기반 뉴스 번역/요약/브리핑 생성, Supabase DB, Firebase 푸시 알림, Finnhub 경제 캘린더를 사용한다. 배포는 Fly.io(백엔드) + Vercel(어드민). 타겟 사용자는 2030 한국인 투자자이며, 다크 프리미엄 디자인 시스템을 따른다.

## 기술 스택

### 백엔드 (Python 3.11+)
- FastAPI, uvicorn, pydantic
- google-genai (Gemini 2.5 Flash Lite — 번역/요약/브리핑)
- supabase (PostgreSQL)
- apscheduler (뉴스 수집 30분, 브리핑 생성 08:35/22:00)
- firebase-admin (FCM 푸시 알림)
- feedparser (RSS 뉴스 수집)
- yfinance (ETF 가격 fallback)
- httpx, slowapi, cachetools, bcrypt, PyJWT, pyotp
- Fly.io 배포 (nixpacks)

### 모바일 (Flutter/Dart)
- Flutter >=3.41.0, Dart >=3.2.0
- 상태관리: flutter_riverpod + riverpod_annotation
- 라우팅: go_router
- HTTP: dio
- 로컬 저장: hive_flutter
- 코드 생성: freezed + json_serializable + build_runner
- 아이콘: lucide_icons
- 푸시: firebase_core + firebase_messaging
- 폰트: Pretendard(한글) + Inter(영문)

### 어드민 대시보드 (Next.js 14)
- React 18, TypeScript, Tailwind CSS
- @supabase/supabase-js, recharts, lucide-react
- Vercel 배포

### 인프라
- DB: Supabase (PostgreSQL, 6개 마이그레이션)
- 푸시: Firebase Admin SDK (FCM)
- 데이터: Finnhub (경제 캘린더), NewsAPI (RSS), yfinance
- CI: GitHub Actions

## 아키텍처 핵심 원칙

1. **비용 최적화가 아키텍처에 내장됨** — 그룹 공유(ETF 비교 그룹별 Gemini 호출 1회), 배치 번역(뉴스 수집 후 백그라운드 번역), Adaptive TTL 캐시(장중 15분/장외 6시간, 메타 7일, 번역 30일)
2. **ETF 유니버스는 동적** — `seeds/etf_master.json`과 `seeds/etf_comparison_groups.json`으로 관리. 코드에 ETF 티커 하드코딩 금지
3. **뉴스 수집은 메인 이벤트 루프를 블로킹하지 않음** — 별도 스레드 + 별도 event loop에서 실행 (`_run_in_thread` 패턴). 이 패턴을 변경하면 서버가 행(hang)됨
4. **번역과 피드는 분리** — RSS 영문 원문 즉시 캐시 → 번역은 백그라운드 → 번역 완료 시 캐시 갱신. API는 항상 캐시에서 즉시 반환
5. **Gemini만 사용** — Anthropic/OpenAI 절대 금지. fallback도 Gemini 계열만 (Flash Lite → Flash → Pro)
6. **Flutter 3-flavor 빌드** — `main_local.dart`(개발), `main_qa.dart`(QA), `main_production.dart`(출시). `app_config.dart`에서 환경별 API URL 분기

## 작업 시 규칙

1. **캐시 TTL 변경 시 `services/cache_ttl.py`만 수정** — `CacheTTL` 클래스에 모든 상수 집중. 다른 파일에 TTL 직접 기입 금지
2. **뉴스 번역 후 피드 캐시 무효화 필수** — 번역 완료 후 `clear_cache()` 호출 누락 시 사용자에게 영문 원문이 보임
3. **Supabase 테이블 변경 시 `backend/migrations/`에 SQL 추가** — 현재 006번까지 존재
4. **프롬프트는 `backend/prompts/`에서 관리** — `translate.py`, `briefing.py`, `impact.py`. 코드 내 프롬프트 하드코딩 금지
5. **어드민 인증** — Google OAuth (Supabase Auth) + JWT. `ADMIN_ALLOWED_EMAILS`로 화이트리스트 관리
6. **Rate limiting** — slowapi 적용. 어드민 로그인은 30/min
7. **디자인 시스템** — `design-system/portfiq/MASTER.md` 참조 필수. 페이지별 오버라이드 파일이 있으면 그것이 우선

## 수정 금지 영역

- `seeds/etf_master.json` — ETF 유니버스 마스터 데이터. 수동 편집 금지, `seed_etf_master.py`로 갱신
- `seeds/etf_comparison_groups.json` — 비교 그룹 정의. 비즈니스 승인 없이 변경 금지
- `seeds/macro_sensitivity.json` — 거시 민감도 매핑
- `backend/migrations/` — 기존 마이그레이션 파일 수정 금지. 신규만 추가
- `apps/mobile/pubspec.yaml`의 폰트 설정 — Pretendard/Inter 폰트 구성 변경 시 글씨 깨짐 발생
- `services/cache.py`의 `_run_in_thread` 패턴 — 변경 시 서버 행(hang)
- `supabase/` 디렉토리 — Edge Functions/설정은 Supabase 대시보드에서 관리

## 테스트/검증 명령어

```bash
# 백엔드 린트
cd projects/portfiq/backend && python3 -m ruff check .

# 백엔드 테스트
cd projects/portfiq/backend && python3 -m pytest

# 출시 준비 스모크 테스트
cd projects/portfiq/backend && PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest tests/test_release_readiness.py

# Flutter 정적 분석
cd projects/portfiq/apps/mobile && flutter analyze

# Flutter 빌드 (프로덕션)
cd projects/portfiq/apps/mobile && flutter build apk --target lib/main_production.dart

# 어드민 빌드
cd projects/portfiq/apps/admin && npm run build

# 백엔드 로컬 실행
cd projects/portfiq/backend && uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## 자주 하는 실수 (git log 기반)

1. **Event loop 블로킹** — 뉴스 수집 Job을 메인 event loop에서 실행하면 `/health` 포함 전체 API가 행(hang). 반드시 별도 스레드+event loop 사용 (3회 반복 수정: fe6dee1, 19df3db, ccec84b)
2. **CORS/OAuth 무한 루프** — Admin 프론트에서 `credentials: "include"` 사용 시 CORS 충돌. Vercel preview URL은 정규식으로 허용 필요 (5회 수정: 697d52b, 731432c, 04e35a3, c3f89d2, 46f4cc9)
3. **캐시 무효화 누락** — 뉴스 번역 완료 후 피드 캐시를 클리어하지 않으면 사용자에게 영문 원문 노출 (40c41cc)
4. **Supabase RLS** — `news` 테이블 INSERT 시 service_role key 미사용 → RLS에 의해 삽입 차단 (ac4b6db)
5. **타임아웃 설정** — Flutter 30초, 백엔드 20초, Admin 5초 각각 별도 설정 필요. 기본값이 너무 짧아서 장애 반복 (f96fa3c, aed4fc5, 46f4cc9)
6. **DB 컬럼명 불일치** — Supabase 테이블의 실제 컬럼명과 코드의 키명이 다를 때 발생 (9a59533: metric_date vs date)
7. **빈 피드 데이터** — RSS 수집은 성공하지만 파싱/저장 로직 오류로 피드가 비어 보이는 문제 (5243b0b)
8. **Flutter lint** — `flutter analyze` 0 issues 유지 필수. 한번에 17건 쌓이면 수정 비용 급증 (e33baee)
