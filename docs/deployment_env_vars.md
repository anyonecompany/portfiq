# Portfiq 배포 환경변수 문서

Railway/Vercel 배포 시 필요한 환경변수 목록입니다.

---

## Backend (Railway)

| 변수명 | 설명 | 필수 여부 | 기본값 |
|--------|------|----------|--------|
| `SUPABASE_URL` | Supabase 프로젝트 URL | **필수** | — |
| `SUPABASE_KEY` | Supabase anon/public 키 (클라이언트용) | **필수** | — |
| `SUPABASE_SERVICE_KEY` | Supabase service role 키 (서버 전용, 관리자 권한) | **필수** | — |
| `ANTHROPIC_API_KEY` | Anthropic API 키 (Claude 브리핑 생성용) | **필수** | — |
| `ANTHROPIC_MODEL` | 사용할 Claude 모델 ID | 선택 | `claude-sonnet-4-20250514` |
| `ADMIN_JWT_SECRET` | 관리자 인증용 JWT 시크릿 키 | **필수** | — |
| `GITHUB_TOKEN` | GitHub API 토큰 (CI/CD 연동, 릴리즈 자동화) | **필수** | — |
| `FIREBASE_CREDENTIALS` | Firebase 서비스 계정 JSON (푸시 알림 발송용) | **필수** | — |
| `ENVIRONMENT` | 배포 환경 식별자 | **필수** | `production` |
| `PORT` | 서버 포트 (Railway 자동 주입) | 자동 | `8000` |
| `CORS_ORIGINS` | 허용 오리진 (쉼표 구분) | 선택 | `http://localhost:3000` |
| `DEBUG` | 디버그 로깅 활성화 | 선택 | `false` |

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

#### `ANTHROPIC_MODEL`
브리핑 생성 시 사용할 Claude 모델. 미설정 시 기본 모델이 사용됩니다.
```
예: claude-sonnet-4-20250514
```

#### `ADMIN_JWT_SECRET`
관리자 API 인증에 사용되는 JWT 서명 키. 최소 32자 이상의 무작위 문자열을 사용하십시오.
```
생성: openssl rand -hex 32
```

#### `GITHUB_TOKEN`
GitHub Personal Access Token. CI/CD 파이프라인, 릴리즈 자동화에 사용됩니다. `repo` 스코프 필요.
```
예: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### `FIREBASE_CREDENTIALS`
Firebase Admin SDK 서비스 계정 JSON. Firebase Console > 프로젝트 설정 > 서비스 계정에서 다운로드. Railway에서는 JSON 문자열을 그대로 환경변수 값으로 입력합니다.
```
예: {"type":"service_account","project_id":"portfiq","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n..."}
```

#### `ENVIRONMENT`
배포 환경 식별자. `production`으로 설정 시 디버그 로깅 비활성화, 프로덕션 CORS 정책 적용.
```
예: production
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
6. Health Check 엔드포인트: `/health`

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
- `FIREBASE_CREDENTIALS` JSON에는 private key가 포함되어 있으므로 환경변수로만 관리합니다.
- 프로덕션 환경에서 `DEBUG`는 반드시 `false`로 설정합니다.
- 환경변수 변경 시 Railway/Vercel에서 자동으로 재배포됩니다.
