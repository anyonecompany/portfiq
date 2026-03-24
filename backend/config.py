"""Application configuration loaded from environment variables."""

import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env from project root (try multiple levels up)
_env_candidates = [
    Path(__file__).resolve().parent / ".env",  # backend/.env
    Path(__file__).resolve().parent.parent / ".env",  # portfiq/.env
    Path(__file__).resolve().parent.parent.parent / ".env",  # projects/.env
    Path(__file__).resolve().parent.parent.parent.parent / ".env",  # ai-dev-team/.env
]
for _env_path in _env_candidates:
    if _env_path.exists():
        load_dotenv(_env_path, override=True)
        break
else:
    load_dotenv()  # fallback: default .env search


class Settings:
    """Central configuration for the Portfiq backend."""

    # Environment
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "local")
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"

    # Server
    HOST: str = os.getenv("HOST", "0.0.0.0")  # nosec B104 — intentional for container deployment
    PORT: int = int(os.getenv("PORT", "8000"))

    # Supabase
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")
    SUPABASE_SERVICE_KEY: str = os.getenv("SUPABASE_SERVICE_KEY", "")

    # Gemini (Google AI for news translation/summarization/briefing)
    GEMINI_API_KEY: str = os.getenv("PORTFIQ_GEMINI_API_KEY", "") or os.getenv(
        "GEMINI_API_KEY", ""
    )
    GEMINI_MODEL: str = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")

    # External data APIs
    NEWS_API_KEY: str = os.getenv("NEWS_API_KEY", "")
    MARKET_DATA_API_KEY: str = os.getenv("MARKET_DATA_API_KEY", "")
    FINNHUB_API_KEY: str = os.getenv("FINNHUB_API_KEY", "")

    # Push notifications (FCM / Firebase Admin SDK)
    FCM_SERVER_KEY: str = os.getenv("FCM_SERVER_KEY", "")
    FIREBASE_SERVICE_ACCOUNT_JSON: str = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "")
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH", "")
    GOOGLE_APPLICATION_CREDENTIALS: str = os.getenv(
        "GOOGLE_APPLICATION_CREDENTIALS", ""
    )

    # CORS
    CORS_ORIGINS: list[str] = os.getenv(
        "CORS_ORIGINS",
        "http://localhost:3000,http://localhost:8080,https://portfiq-admin.vercel.app,https://admin-seven-nu-34.vercel.app",
    ).split(",")

    # Briefing schedule
    BRIEFING_MORNING_HOUR: int = int(os.getenv("BRIEFING_MORNING_HOUR", "8"))
    BRIEFING_MORNING_MINUTE: int = int(os.getenv("BRIEFING_MORNING_MINUTE", "35"))
    BRIEFING_NIGHT_HOUR: int = int(os.getenv("BRIEFING_NIGHT_HOUR", "22"))

    # Admin
    ADMIN_JWT_SECRET: str = os.getenv("ADMIN_JWT_SECRET", "")
    ADMIN_ALLOWED_EMAILS: list[str] = os.getenv(
        "ADMIN_ALLOWED_EMAILS",
        "hyeonsong@anyonecompany.kr,geonyong@anyonecompany.kr",
    ).split(",")

    # Admin role mapping (email → role)
    ADMIN_ROLE_MAP: dict[str, str] = {
        "hyeonsong@anyonecompany.kr": "cto",
        "geonyong@anyonecompany.kr": "ceo",
    }

    # Deploy (GitHub Actions)
    GITHUB_TOKEN: str = os.getenv("GITHUB_TOKEN", "")
    GITHUB_REPO: str = os.getenv("GITHUB_REPO", "")
    GITHUB_WORKFLOW_ID: str = os.getenv("GITHUB_WORKFLOW_ID", "deploy.yml")

    # Analytics
    MIXPANEL_TOKEN: str = os.getenv("MIXPANEL_TOKEN", "")


settings = Settings()
