"""Application configuration loaded from environment variables."""

import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env from project root (try multiple levels up)
_env_candidates = [
    Path(__file__).resolve().parent / ".env",           # backend/.env
    Path(__file__).resolve().parent.parent / ".env",    # portfiq/.env
    Path(__file__).resolve().parent.parent.parent / ".env",  # projects/.env
    Path(__file__).resolve().parent.parent.parent.parent / ".env",  # ai-dev-team/.env
]
for _env_path in _env_candidates:
    if _env_path.exists():
        load_dotenv(_env_path)
        break
else:
    load_dotenv()  # fallback: default .env search


class Settings:
    """Central configuration for the Portfiq backend."""

    # Environment
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "local")
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Server
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))

    # Supabase
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")
    SUPABASE_SERVICE_KEY: str = os.getenv("SUPABASE_SERVICE_KEY", "")

    # Anthropic (Claude API for briefing generation)
    ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")
    ANTHROPIC_MODEL: str = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-20250514")

    # External data APIs
    NEWS_API_KEY: str = os.getenv("NEWS_API_KEY", "")
    MARKET_DATA_API_KEY: str = os.getenv("MARKET_DATA_API_KEY", "")

    # Push notifications (FCM / Firebase Admin SDK)
    FCM_SERVER_KEY: str = os.getenv("FCM_SERVER_KEY", "")
    FIREBASE_SERVICE_ACCOUNT_JSON: str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
    GOOGLE_APPLICATION_CREDENTIALS: str = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")

    # CORS
    CORS_ORIGINS: list[str] = os.getenv(
        "CORS_ORIGINS", "http://localhost:3000,http://localhost:8080"
    ).split(",")

    # Briefing schedule
    BRIEFING_MORNING_HOUR: int = int(os.getenv("BRIEFING_MORNING_HOUR", "8"))
    BRIEFING_MORNING_MINUTE: int = int(os.getenv("BRIEFING_MORNING_MINUTE", "35"))
    BRIEFING_NIGHT_HOUR: int = int(os.getenv("BRIEFING_NIGHT_HOUR", "22"))

    # Admin
    ADMIN_JWT_SECRET: str = os.getenv("ADMIN_JWT_SECRET", "")

    # Deploy (GitHub Actions)
    GITHUB_TOKEN: str = os.getenv("GITHUB_TOKEN", "")
    GITHUB_REPO: str = os.getenv("GITHUB_REPO", "")
    GITHUB_WORKFLOW_ID: str = os.getenv("GITHUB_WORKFLOW_ID", "deploy.yml")

    # Analytics
    MIXPANEL_TOKEN: str = os.getenv("MIXPANEL_TOKEN", "")


settings = Settings()
