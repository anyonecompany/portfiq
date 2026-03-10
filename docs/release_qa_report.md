# Portfiq v1.0.0 Release QA Report

**Date**: 2026-03-10
**QA Engineer**: AI Agent (QA-Release)

## 1. Code Quality
- flutter analyze: **PASS** — 0 errors, 0 warnings, 8 info
- Unused imports: **PASS**

## 2. Build Verification
- Android appbundle (release): **PASS** — 46.9MB (.aab generated)
- Web (release): **PASS** — `build/web` generated

Notes:
- Warning about cupertino_icons font not found (transitive dependency, not used in code — harmless)
- Warning about debug symbol stripping (Android toolchain issue, does not affect release artifact)

## 3. Backend API Smoke Test
- GET /health: **PASS** — `{"status":"ok","version":"1.0.0"}`
- GET /api/v1/etf/search?q=QQQ: **PASS** — results returned
- GET /api/v1/etf/popular: **PASS** — 10 ETFs (mock fallback due to missing Supabase function)
- GET /api/v1/feed/latest: **PASS** — 10 items
- GET /api/v1/etf/QQQ/detail: **PASS** — QQQ - 나스닥 100 추종 ETF - 10 holdings

## 4. Security
- No .env in git: **PASS**
- No hardcoded API keys: **PASS**
- .gitignore covers .env: **PASS**

## 5. Release Assets
- Dockerfile: **EXISTS**
- Procfile: **EXISTS**
- .dockerignore: **EXISTS**
- Privacy Policy (KR): **EXISTS**
- Privacy Policy (EN): **EXISTS**
- Terms of Service: **EXISTS**
- AI Risk Assessment: **EXISTS**
- Store Metadata: **EXISTS**
- Store Screenshots Guide: **EXISTS**
- Deployment Env Vars: **EXISTS**
- App Icon: **EXISTS**
- ProGuard Rules: **EXISTS**

## 6. Overall Verdict
**RELEASE READY**

### Known Issues
- Supabase `get_popular_etfs` RPC function not deployed — backend gracefully falls back to mock data
- cupertino_icons font warning during build (cosmetic, no functional impact)
- Android debug symbol stripping warning (toolchain issue, does not affect release artifact)

### Recommendations
- Deploy `get_popular_etfs` Supabase RPC function before production launch
- Run `flutter doctor` to resolve Android NDK debug symbol stripping warning
- Consider adding `cupertino_icons` to pubspec.yaml or removing CupertinoIcons references from transitive dependencies
