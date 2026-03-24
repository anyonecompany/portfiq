# Vercel 배포 설정

## GitHub 연동 (1회만 설정)

1. https://vercel.com/new 접속
2. "Import Git Repository" → GitHub 레포 선택
3. "Root Directory" → `projects/portfiq/apps/admin` 설정
4. "Framework Preset" → Next.js 선택
5. 환경변수 추가 (아래 참조)
6. "Deploy" 클릭

## 이후 자동 배포

- `main` 브랜치 push → 자동 프로덕션 배포
- PR 생성 → 자동 프리뷰 배포
- `projects/portfiq/apps/admin/` 외 변경 → 배포 스킵 (ignoreCommand)

## 환경변수

Vercel 대시보드 → Settings → Environment Variables:
- `NEXT_PUBLIC_API_URL`: 백엔드 API URL (예: https://portfiq.fly.dev)
- `NEXT_PUBLIC_SUPABASE_URL`: Supabase URL
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`: Supabase anon key
