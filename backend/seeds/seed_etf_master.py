"""ETF 마스터 데이터 시딩 스크립트.

Supabase etf_master 테이블에 30개 인기 서학 ETF 데이터를 업로드한다.
기존 데이터가 있으면 ticker 기준으로 upsert 처리.

현재 Supabase 스키마:
  - ticker TEXT UNIQUE NOT NULL
  - name TEXT NOT NULL
  - description TEXT
  - category TEXT
  - expense_ratio NUMERIC(5,4)
  - top_holdings TEXT[]  (text array — 티커 문자열만)

name_kr과 구조화된 top_holdings는 etf_master.json에 있으나
Supabase 스키마에 맞게 변환하여 삽입한다.

Usage:
    cd projects/portfiq/backend
    python seeds/seed_etf_master.py
"""

from __future__ import annotations

import json
import logging
import sys
from pathlib import Path

# backend/ 를 sys.path에 추가
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from config import settings

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


def _convert_for_supabase(etf: dict) -> dict:
    """etf_master.json 항목을 Supabase 스키마에 맞게 변환한다.

    - name_kr → description 필드에 저장 (name_kr: description 형태)
    - top_holdings → TEXT[] 형태로 변환 (티커 문자열 리스트)
    """
    holdings_raw = etf.get("top_holdings", [])
    if holdings_raw and isinstance(holdings_raw[0], dict):
        # "AAPL 8.9%" 형태로 변환
        holdings_text = [
            f"{h.get('ticker', '')} {h.get('weight', 0)}%" for h in holdings_raw
        ]
    else:
        holdings_text = [str(h) for h in holdings_raw]

    name_kr = etf.get("name_kr", "")
    description = f"{name_kr}" if name_kr else ""

    return {
        "ticker": etf["ticker"],
        "name": etf["name"],
        "description": description,
        "category": etf.get("category", ""),
        "expense_ratio": etf.get("expense_ratio", 0.0),
        "top_holdings": holdings_text,
    }


def seed() -> None:
    """etf_master.json을 읽어 Supabase etf_master 테이블에 upsert한다."""
    json_path = Path(__file__).resolve().parent / "etf_master.json"
    if not json_path.exists():
        logger.error("etf_master.json not found at %s", json_path)
        sys.exit(1)

    with open(json_path, encoding="utf-8") as f:
        etfs: list[dict] = json.load(f)

    logger.info("Loading %d ETFs from %s", len(etfs), json_path.name)

    # Use service_role key for write access (bypasses RLS)
    from supabase import create_client

    key = settings.SUPABASE_SERVICE_KEY or settings.SUPABASE_KEY
    sb = create_client(settings.SUPABASE_URL, key)
    success = 0
    for etf in etfs:
        row = _convert_for_supabase(etf)
        try:
            sb.table("etf_master").upsert(row, on_conflict="ticker").execute()
            logger.info("  ✓ %s — %s", row["ticker"], row["description"])
            success += 1
        except Exception as e:
            logger.error("  ✗ %s — %s", row["ticker"], e)

    logger.info("\n%d / %d ETFs seeded successfully.", success, len(etfs))


if __name__ == "__main__":
    seed()
