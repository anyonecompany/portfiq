# Portfiq

AI-powered ETF briefing app. Get personalized daily briefings on your ETF portfolio, powered by Claude.

## Structure

```
portfiq/
├── apps/mobile/     Flutter app (Dart)
├── apps/admin/      Admin dashboard (Phase 3)
├── backend/         FastAPI backend (Python)
├── docs/            API spec, event schema
└── .github/         CI/CD workflows
```

## Quick Start

```bash
# Backend
make install-backend
cp .env.example .env   # fill in values
make backend-run

# Flutter
cd apps/mobile
flutter pub get
make flutter-run
```

## Tech Stack

- **Mobile:** Flutter 3.41+ / Riverpod / GoRouter / Hive
- **Backend:** FastAPI / Supabase / Anthropic Claude API
- **Infra:** Docker / GitHub Actions
