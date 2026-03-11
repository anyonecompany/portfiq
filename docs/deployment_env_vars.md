# Portfiq 배포 환경변수 문서

Railway/Vercel 배포 시 필요한 환경변수 목록입니다.

---

## Backend (Railway)

### 필수 환경변수

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `SUPABASE_URL` | Supabase 프로젝트 URL | — |
| `SUPABASE_KEY` | Supabase anon/public 키 (클라이언트용) | — |
| `SUPABASE_SERVICE_KEY` | Supabase service role 키 (서버 전용, RLS 우회) | — |
| `ANTHROPIC_API_KEY` | Anthropic API 키 (Claude 브리핑 생성용) | — |
| `ADMIN_JWT_SECRET` | 관리자 인증용 JWT 시크릿 키 (최소 32자) | — |
| `ENVIRONMENT` | 배포 환경 식별자 | `local` |

### 선택 환경변수

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `PORT` | 서버 포트 (Railway 자동 주입) | `8000` |
| `HOST` | 서버 바인딩 호스트 | `0.0.0.0` |
| `DEBUG` | 디버그 로깅 활성화 | `false` |
| `CORS_ORIGINS` | 허용 오리진 (쉼표 구분) | `http://localhost:3000,http://localhost:8080` |
| `ANTHROPIC_MODEL` | 사용할 Claude 모델 ID | `claude-sonnet-4-20250514` |

### 외부 데이터 API

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `NEWS_API_KEY` | 뉴스 API 키 | — |
| `MARKET_DATA_API_KEY` | 시장 데이터 API 키 | — |

### Firebase / 푸시 알림 (택 1)

Firebase 인증은 아래 3가지 방법 중 하나를 선택합니다. **Railway에서는 `FIREBASE_SERVICE_ACCOUNT_JSON` 권장.**

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase 서비스 계정 JSON 문자열 (Railway 권장) | — |
| `FIREBASE_CREDENTIALS_PATH` | Firebase 서비스 계정 JSON 파일 경로 | — |
| `GOOGLE_APPLICATION_CREDENTIALS` | GCP Application Default Credentials 파일 경로 | — |
| `FCM_SERVER_KEY` | FCM 서버 키 (레거시, 미사용) | — |

### 브리핑 스케줄

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `BRIEFING_MORNING_HOUR` | 모닝 브리핑 시각 (시) | `8` |
| `BRIEFING_MORNING_MINUTE` | 모닝 브리핑 시각 (분) | `35` |
| `BRIEFING_NIGHT_HOUR` | 나이트 브리핑 시각 (시) | `22` |

### CI/CD & 기타

| 변수명 | 설명 | 기본값 |
|--------|------|--------|
| `GITHUB_TOKEN` | GitHub API 토큰 (CI/CD 연동) | — |
| `GITHUB_REPO` | GitHub 리포지토리 (owner/repo) | — |
| `GITHUB_WORKFLOW_ID` | GitHub Actions 워크플로우 ID | `deploy.yml` |
| `MIXPANEL_TOKEN` | Mixpanel 분석 토큰 | — |

### 변수 상세 설명

#### `SUPABASE_URL`
Supabase 프로젝트의 REST API URL. Supabase 대시보드 > Settings > API에서 확인.
```
예: https://xxxxxxxxxxxx.supabase.co
```

#### `SUPABASE_KEY`
클라이언트 측에서 사용하는 anon/public 키. Row Level Security(RLS) 정책에 의해 접근이 제한됩니다.
```
예: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### `SUPABASE_SERVICE_KEY`
서버 측 전용 service role 키. RLS를 우회하여 모든 데이터에 접근 가능하므로 **절대 클라이언트에 노출하지 마십시오**.
```
예: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### `ANTHROPIC_API_KEY`
Anthropic Console에서 발급받은 API 키. 뉴스 분석, 브리핑 생성, 영향도 분류, ETF 비교에 사용됩니다.
```
예: sk-ant-api03-...
```

#### `ADMIN_JWT_SECRET`
관리자 API 인증에 사용되는 JWT 서명 키. 최소 32자 이상의 무작위 문자열을 사용하십시오.
```
생성: openssl rand -hex 32
```

#### `FIREBASE_SERVICE_ACCOUNT_JSON`
Firebase Admin SDK 서비스 계정 JSON 문자열. Firebase Console > 프로젝트 설정 > 서비스 계정에서 다운로드한 JSON을 그대로 환경변수 값으로 입력합니다. Railway 배포 시 이 방법을 권장합니다.
```
예: {"type":"service_account","project_id":"portfiq","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n..."}
```

#### `CORS_ORIGINS`
쉼표로 구분된 허용 오리진 목록. 프로덕션에서는 실제 프론트엔드 도메인을 설정합니다.
```
예: https://portfiq.com,https://www.portfiq.com,https://admin.portfiq.com
```

---

## Admin (Vercel)

| 변수명 | 설명 | 필수 여부 | 기본값 |
|--------|------|----------|--------|
| `NEXT_PUBLIC_API_URL` | 백엔드 API 서버 URL (Railway 배포 주소) | **필수** | — |
| `NEXT_PUBLIC_ADMIN_KEY` | 관리자 대시보드 인증 키 | **필수** | — |

### 변수 상세 설명

#### `NEXT_PUBLIC_API_URL`
Railway에 배포된 백엔드 API 서버의 URL. `NEXT_PUBLIC_` 접두사로 클라이언트 번들에 포함됩니다.
```
예: https://portfiq-backend-production.up.railway.app
```

#### `NEXT_PUBLIC_ADMIN_KEY`
관리자 대시보드에서 백엔드 API 호출 시 사용하는 인증 키. 백엔드의 `ADMIN_JWT_SECRET`과 쌍을 이룹니다.
```
예: admin_key_xxxxxxxxxxxxxxxx
```

---

## Railway 배포 설정

1. Railway에서 새 프로젝트를 생성합니다.
2. GitHub 리포지토리를 연결합니다.
3. 루트 디렉토리를 `projects/portfiq/backend`로 설정합니다.
4. 위 **Backend** 섹션의 모든 필수 환경변수를 Railway 대시보드에서 설정합니다.
5. `PORT`는 Railway가 자동으로 주입하므로 수동 설정하지 마십시오.
6. Health Check 경로: `/health`
7. 빌드 명령어: Docker (자동 감지, Dockerfile 사용)

## Vercel 배포 설정

1. Vercel에서 새 프로젝트를 생성합니다.
2. GitHub 리포지토리를 연결합니다.
3. 루트 디렉토리를 관리자 프론트엔드 경로로 설정합니다.
4. 위 **Admin** 섹션의 모든 필수 환경변수를 Vercel 대시보드에서 설정합니다.
5. 빌드 명령어와 출력 디렉토리가 올바른지 확인합니다.

## 프로덕션 CORS 설정

백엔드의 `CORS_ORIGINS`를 프로덕션 프론트엔드 도메인으로 설정합니다.
```
CORS_ORIGINS=https://portfiq.com,https://www.portfiq.com,https://admin.portfiq.com
```

## 보안 주의사항

- `SUPABASE_SERVICE_KEY`, `ADMIN_JWT_SECRET`, `ANTHROPIC_API_KEY`는 절대 클라이언트 코드나 Git에 노출하지 마십시오.
- `FIREBASE_SERVICE_ACCOUNT_JSON`에는 private key가 포함되어 있으므로 환경변수로만 관리합니다.
- 프로덕션 환경에서 `DEBUG`는 반드시 `false`로 설정합니다.
- 환경변수 변경 시 Railway/Vercel에서 자동으로 재배포됩니다.
