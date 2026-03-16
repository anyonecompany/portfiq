.PHONY: dev backend-run flutter-run install-backend lint test test-smoke clean

# Run both backend and flutter (requires tmux or separate terminals)
dev:
	@echo "Start backend and flutter in separate terminals:"
	@echo "  make backend-run"
	@echo "  make flutter-run"

# Backend
install-backend:
	cd backend && python3 -m pip install -r requirements.txt

backend-run:
	cd backend && uvicorn main:app --host 0.0.0.0 --port 8000 --reload

backend-docker:
	docker-compose up --build backend

# Flutter
flutter-run:
	cd apps/mobile && flutter run --target lib/main_local.dart

flutter-run-qa:
	cd apps/mobile && flutter run --target lib/main_qa.dart

flutter-build:
	cd apps/mobile && flutter build apk --target lib/main_production.dart

# Quality
lint:
	cd backend && python3 -m ruff check .

test:
	cd backend && python3 -m pytest

test-smoke:
	cd backend && PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 python3 -m pytest tests/test_release_readiness.py

clean:
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type d -name .pytest_cache -exec rm -rf {} +
	cd apps/mobile && flutter clean 2>/dev/null || true
