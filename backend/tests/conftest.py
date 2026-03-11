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

    from main import app
    with TestClient(app) as c:
        yield c
