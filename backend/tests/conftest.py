"""Shared test fixtures for Portfiq backend."""

import os
import sys

import pytest
from fastapi.testclient import TestClient

# Ensure backend dir is on sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


@pytest.fixture(scope="session")
def client():
    """Create a FastAPI TestClient that reuses one app instance."""
    os.environ.setdefault("ENVIRONMENT", "test")
    os.environ.setdefault("DEBUG", "false")
    # Force in-memory fallback by clearing Supabase credentials for tests
    os.environ["SUPABASE_URL"] = ""
    os.environ["SUPABASE_KEY"] = ""
    os.environ["SUPABASE_SERVICE_KEY"] = ""

    # Reset Supabase singleton so it picks up empty credentials
    import services.supabase_client as sbc

    sbc._client = None
    sbc._service_client = None

    # Reset config to pick up test env vars
    import config

    config.settings = config.Settings()

    from main import app

    with TestClient(app) as c:
        yield c
