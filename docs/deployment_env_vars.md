# Portfiq 배포 환경변수 문서

Fly.io 배포 시 필요한 환경변수 목록입니다.

---

## Backend (Fly.io)

### 필수 환경변수

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `SUPABASE_URL` | Supabase 프로젝트 URL | -- |
| `SUPABASE_KEY` | Supabase anon/public 키 (클라이언트용) | -- |
| `SUPABASE_SERVICE_KEY` | Supabase service role 키 (서버 전용, RLS 우회) | -- |
| `GEMINI_API_KEY` | Google Gemini API 키 (브리핑/뉴스 분석용) | -- |
| `ADMIN_JWT_SECRET` | 관리자 인증용 JWT 시크릿 키 (최소 32자) | -- |
| `ENVIRONMENT` | 배포 환경 식별자 | `local` |

### 선택 환경변수

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `PORT` | 서버 포트 | `8000` |
| `HOST` | 서버 바인딩 호스트 | `0.0.0.0` |
| `DEBUG` | 디버그 로깅 활성화 | `false` |
| `GEMINI_MODEL` | 사용할 Gemini 모델 ID | `gemini-2.5-flash-lite` |
| `CORS_ORIGINS` | 허용 오리진 (쉼표 구분) | `http://localhost:3000,http://localhost:8080,https://portfiq-admin.vercel.app,https://admin-seven-nu-34.vercel.app` |
| `ADMIN_ALLOWED_EMAILS` | 관리자 허용 이메일 (쉼표 구분) | `hyeonsong@anyonecompany.kr,geonyong@anyonecompany.kr` |

### 외부 데이터 API (선택)

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `NEWS_API_KEY` | 뉴스 수집 API 키 | -- |
| `MARKET_DATA_API_KEY` | 시장 데이터 API 키 | -- |

### Firebase / 푸시 알림 (선택)

Firebase 인증은 아래 방법 중 하나를 선택합니다. **Fly.io에서는 `FIREBASE_SERVICE_ACCOUNT_JSON` 권장.**

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase 서비스 계정 JSON 문자열 (Fly.io 권장) | -- |
| `FIREBASE_CREDENTIALS_PATH` | Firebase 서비스 계정 JSON 파일 경로 | -- |
| `GOOGLE_APPLICATION_CREDENTIALS` | GCP Application Default Credentials 파일 경로 | -- |
| `FCM_SERVER_KEY` | FCM 서버 키 (레거시) | -- |

### 브리핑 스케줄

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `BRIEFING_MORNING_HOUR` | 모닝 브리핑 시각 (시) | `8` |
| `BRIEFING_MORNING_MINUTE` | 모닝 브리핑 시각 (분) | `35` |
| `BRIEFING_NIGHT_HOUR` | 나이트 브리핑 시각 (시) | `22` |

### CI/CD & 기타 (선택)

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `GITHUB_TOKEN` | GitHub API 토큰 (CI/CD 연동) | -- |
| `GITHUB_REPO` | GitHub 리포지토리 (owner/repo) | -- |
| `GITHUB_WORKFLOW_ID` | GitHub Actions 워크플로우 ID | `deploy.yml` |
| `MIXPANEL_TOKEN` | Mixpanel 분석 토큰 | -- |

---

## 변수 상세 설명

### `SUPABASE_URL`
Supabase 프로젝트의 REST API URL. Supabase 대시보드 > Settings > API에서 확인.
```
예: https://xxxxxxxxxxxx.supabase.co
```

### `SUPABASE_KEY`
클라이언트 측에서 사용하는 anon/public 키. Row Level Security(RLS) 정책에 의해 접근이 제한됩니다.
```
예: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### `SUPABASE_SERVICE_KEY`
서버 측 전용 service role 키. RLS를 우회하여 모든 데이터에 접근 가능하므로 **절대 클라이언트에 노출하지 마십시오**.
```
예: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### `GEMINI_API_KEY`
Google AI Studio에서 발급받은 Gemini API 키. 뉴스 번역/요약, 브리핑 생성, 영향도 분류에 사용됩니다.
```
예: AIzaSy...
```

### `ADMIN_JWT_SECRET`
관리자 API 인증에 사용되는 JWT 서명 키. 최소 32자 이상의 무작위 문자열을 사용하십시오.
```
생성: openssl rand -hex 32
```

### `FIREBASE_SERVICE_ACCOUNT_JSON`
Firebase Admin SDK 서비스 계정 JSON 문자열. Firebase Console > 프로젝트 설정 > 서비스 계정에서 다운로드한 JSON을 그대로 환경변수 값으로 입력합니다.

Fly.io에서 JSON 값을 설정할 때는 따옴표로 감싸야 합니다:
```bash
flyctl secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"portfiq",...}' -a portfiq
```

### `CORS_ORIGINS`
쉼표로 구분된 허용 오리진 목록. 프로덕션에서는 실제 프론트엔드 도메인을 설정합니다.
```
예: https://portfiq.com,https://www.portfiq.com,https://admin.portfiq.com
```

---

## Fly.io 배포 가이드

### 사전 준비

flyctl CLI가 설치되어 있어야 합니다:
```bash
# PATH에 flyctl 추가
export PATH="$HOME/.fly/bin:$PATH"

# 로그인 확인
flyctl auth whoami
```

### 환경변수 설정 (Secrets)

Fly.io에서 환경변수는 `flyctl secrets` 명령으로 관리합니다. Secrets는 암호화되어 저장되며, 설정 시 자동으로 앱이 재배포됩니다.

#### 필수 변수 일괄 설정

```bash
# 프로덕션 필수 환경변수 설정
flyctl secrets set \
  ENVIRONMENT=production \
  DEBUG=false \
  SUPABASE_URL="https://xxxxxxxxxxxx.supabase.co" \
  SUPABASE_KEY="eyJ..." \
  SUPABASE_SERVICE_KEY="eyJ..." \
  GEMINI_API_KEY="AIzaSy..." \
  ADMIN_JWT_SECRET="$(openssl rand -hex 32)" \
  -a portfiq
```

#### 개별 변수 설정

```bash
# 단일 변수 설정
flyctl secrets set KEY=value -a portfiq

# 예시
flyctl secrets set GEMINI_MODEL=gemini-2.5-flash-lite -a portfiq
flyctl secrets set NEWS_API_KEY="your-news-api-key" -a portfiq
flyctl secrets set FCM_SERVER_KEY="your-fcm-key" -a portfiq
flyctl secrets set CORS_ORIGINS="https://portfiq.com,https://admin.portfiq.com" -a portfiq
flyctl secrets set ADMIN_ALLOWED_EMAILS="hyeonsong@anyonecompany.kr,geonyong@anyonecompany.kr" -a portfiq
```

#### 브리핑 스케줄 설정

```bash
flyctl secrets set \
  BRIEFING_MORNING_HOUR=8 \
  BRIEFING_MORNING_MINUTE=35 \
  BRIEFING_NIGHT_HOUR=22 \
  -a portfiq
```

#### 현재 설정된 변수 확인

```bash
# 변수 목록 확인 (값은 표시되지 않음)
flyctl secrets list -a portfiq
```

#### 변수 삭제

```bash
flyctl secrets unset KEY_NAME -a portfiq
```

### 배포

```bash
# PATH 설정
export PATH="$HOME/.fly/bin:$PATH"

# 원격 빌더로 배포 (로컬 Docker 불필요)
flyctl deploy -a portfiq --remote-only
```

### 배포 후 확인

```bash
# 앱 상태 확인
flyctl status -a portfiq

# 로그 확인
flyctl logs -a portfiq

# Health Check
curl https://portfiq.fly.dev/health
```

---

## Admin (Vercel)

| 변수명 | 설명 | 필수 여부 | 기본값 |
|--------|------|----------|--------|
| `NEXT_PUBLIC_API_URL` | 백엔드 API 서버 URL (Fly.io 배포 주소) | **필수** | -- |
| `NEXT_PUBLIC_ADMIN_KEY` | 관리자 대시보드 인증 키 | **필수** | -- |

### 변수 상세 설명

#### `NEXT_PUBLIC_API_URL`
Fly.io에 배포된 백엔드 API 서버의 URL. `NEXT_PUBLIC_` 접두사로 클라이언트 번들에 포함됩니다.
```
예: https://portfiq.fly.dev
```

#### `NEXT_PUBLIC_ADMIN_KEY`
관리자 대시보드에서 백엔드 API 호출 시 사용하는 인증 키. 백엔드의 `ADMIN_JWT_SECRET`과 쌍을 이룹니다.
```
예: admin_key_xxxxxxxxxxxxxxxx
```

---

## 프로덕션 CORS 설정

백엔드의 `CORS_ORIGINS`를 프로덕션 프론트엔드 도메인으로 설정합니다:
```bash
flyctl secrets set CORS_ORIGINS="https://portfiq.com,https://www.portfiq.com,https://admin.portfiq.com,https://portfiq-admin.vercel.app" -a portfiq
```

---

## 보안 주의사항

- `SUPABASE_SERVICE_KEY`, `ADMIN_JWT_SECRET`, `GEMINI_API_KEY`는 절대 클라이언트 코드나 Git에 노출하지 마십시오.
- `FIREBASE_SERVICE_ACCOUNT_JSON`에는 private key가 포함되어 있으므로 환경변수로만 관리합니다.
- 프로덕션 환경에서 `DEBUG`는 반드시 `false`로 설정합니다.
- Fly.io secrets는 암호화되어 저장되며, `flyctl secrets list`로 값 자체는 확인할 수 없습니다.
- 환경변수 변경 시 Fly.io에서 자동으로 재배포됩니다.

---

## Railway에서 Fly.io 마이그레이션 체크리스트

1. `flyctl secrets list -a portfiq`로 현재 설정된 변수 확인
2. Railway에 설정된 모든 환경변수를 `flyctl secrets set`으로 이전
3. `NEXT_PUBLIC_API_URL`을 Fly.io 주소(`https://portfiq.fly.dev`)로 변경
4. CORS_ORIGINS에 새 도메인 추가
5. Health Check 확인: `curl https://portfiq.fly.dev/health`
6. DNS/도메인이 있다면 Fly.io로 재지정
