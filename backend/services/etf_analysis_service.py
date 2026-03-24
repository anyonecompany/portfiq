"""ETF 분석 서비스 — 섹터 집중도, 매크로 민감도, ETF 비교, 보유종목 변동.

리텐션 방어 엔진의 분석 API를 위한 핵심 서비스 모듈.
Gemini API를 활용한 ETF 비교 요약 생성과 seed 데이터 기반 정적 분석을 제공한다.

두 가지 인터페이스를 제공한다:
1. EtfAnalysisService 클래스 (기존 etf.py 라우터 호환)
2. 독립 함수 (etf_analysis.py 라우터용): get_sector_concentration, get_macro_sensitivity, get_etf_comparison
"""

from __future__ import annotations

import hashlib
import json
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# 5변수 매크로 민감도 (data/macro_sensitivity.json)
# ──────────────────────────────────────────────

_MACRO_DATA: dict[str, dict] | None = None


def _load_macro_data() -> dict[str, dict]:
    """data/macro_sensitivity.json에서 5변수 매크로 민감도를 로드한다.

    Returns:
        ticker -> {interest_rate, inflation, usd_strength, oil_price, employment} 매핑.
    """
    global _MACRO_DATA
    if _MACRO_DATA is None:
        path = Path(__file__).parent.parent / "data" / "macro_sensitivity.json"
        try:
            with open(path, encoding="utf-8") as f:
                _MACRO_DATA = json.load(f)
        except Exception as e:
            logger.warning("data/macro_sensitivity.json 로드 실패: %s", e)
            _MACRO_DATA = {}
    return _MACRO_DATA


# ──────────────────────────────────────────────
# 독립 함수 API (routers/etf_analysis.py 용)
# ──────────────────────────────────────────────


async def get_sector_concentration(ticker: str) -> dict[str, Any]:
    """ETF 구성종목의 섹터 집중도 분석.

    Supabase etf_master 테이블에서 보유종목 정보를 가져와
    섹터별 비중을 계산한다. 단일 섹터 50% 초과 시 경고를 생성한다.

    Args:
        ticker: ETF 티커 심볼.

    Returns:
        {ticker, category, sectors: [{name, weight}], concentration_warning}
    """
    from services.supabase_client import get_supabase

    try:
        sb = get_supabase()
        result = (
            sb.table("etf_master")
            .select("top_holdings, category")
            .eq("ticker", ticker.upper())
            .single()
            .execute()
        )
    except Exception as e:
        logger.warning("섹터 집중도 조회 실패 (%s): %s", ticker, e)
        return {"ticker": ticker, "sectors": [], "concentration_warning": None}

    if not result.data:
        return {"ticker": ticker, "sectors": [], "concentration_warning": None}

    holdings = result.data.get("top_holdings", [])
    category = result.data.get("category", "")

    # 섹터별 가중치 합산
    sector_map: dict[str, float] = {}
    for h in holdings:
        sector = h.get("sector", "기타")
        weight = h.get("weight", 0)
        sector_map[sector] = sector_map.get(sector, 0) + weight

    sectors = [
        {"name": k, "weight": round(v, 2), "percentage": round(v, 2)}
        for k, v in sorted(sector_map.items(), key=lambda x: -x[1])
    ]

    # 단일 섹터 50% 초과 경고
    warning = None
    if sectors and sectors[0]["weight"] > 50:
        warning = f"{sectors[0]['name']} 섹터에 {sectors[0]['weight']}% 집중되어 있습니다. 분산 투자를 고려하세요."

    return {
        "ticker": ticker,
        "category": category,
        "sectors": sectors,
        "concentration_warning": warning,
    }


async def get_macro_sensitivity(ticker: str) -> dict[str, Any]:
    """ETF의 거시경제 변수 민감도 조회 (5변수).

    data/macro_sensitivity.json에서 금리, 인플레이션, 달러 강세,
    유가, 고용 5개 변수에 대한 민감도를 반환한다.

    Args:
        ticker: ETF 티커 심볼.

    Returns:
        {ticker, sensitivities: [{factor, factor_key, impact, impact_key}], summary}
    """
    data = _load_macro_data()
    sensitivity = data.get(ticker.upper(), {})

    if not sensitivity:
        return {"ticker": ticker, "sensitivities": [], "summary": "데이터 없음"}

    LABELS = {
        "interest_rate": "금리",
        "inflation": "인플레이션",
        "usd_strength": "달러 강세",
        "oil_price": "유가",
        "employment": "고용",
    }

    IMPACT_LABELS = {
        "high_positive": "강한 호재",
        "medium_positive": "약한 호재",
        "low": "영향 미미",
        "medium_negative": "약한 악재",
        "high_negative": "강한 악재",
    }

    sensitivities = []
    for key, value in sensitivity.items():
        sensitivities.append(
            {
                "factor": LABELS.get(key, key),
                "factor_key": key,
                "impact": IMPACT_LABELS.get(value, value),
                "impact_key": value,
            }
        )

    # 강한 영향 요인 요약
    strong = [s for s in sensitivities if "high" in s["impact_key"]]
    if strong:
        summary = "주의: " + ", ".join(f"{s['factor']}({s['impact']})" for s in strong)
    else:
        summary = "전반적으로 거시경제 변수에 대한 민감도가 낮습니다."

    # Frontend-compatible aliases (usd_strength→dollar, oil_price→oil)
    _FE_KEY_ALIASES = {"usd_strength": "dollar", "oil_price": "oil"}

    # Flat map for frontend compatibility (key → impact label, key_explanation → impact)
    flat_map: dict[str, str] = {}
    for s in sensitivities:
        key = s["factor_key"]
        fe_key = _FE_KEY_ALIASES.get(key, key)
        flat_map[fe_key] = s["impact"]
        flat_map[f"{fe_key}_explanation"] = s["impact"]

    return {
        "ticker": ticker,
        "sensitivities": sensitivities,
        "summary": summary,
        **flat_map,
    }


async def get_etf_comparison(ticker: str) -> dict[str, Any]:
    """같은 카테고리 ETF들과 비교.

    Supabase etf_master에서 동일 카테고리 ETF를 최대 5개 조회하여
    보수율 기준으로 정렬 비교한다.

    Args:
        ticker: ETF 티커 심볼.

    Returns:
        {ticker, category, comparisons: [{ticker, name, expense_ratio, is_current}]}
    """
    from services.supabase_client import get_supabase

    try:
        sb = get_supabase()

        # 해당 ETF의 카테고리 조회
        result = (
            sb.table("etf_master")
            .select("*")
            .eq("ticker", ticker.upper())
            .single()
            .execute()
        )
        if not result.data:
            return {"ticker": ticker, "comparisons": []}

        category = result.data.get("category", "")

        # 같은 카테고리 ETF 조회
        peers_result = (
            sb.table("etf_master")
            .select("ticker, name, category, expense_ratio")
            .eq("category", category)
            .limit(5)
            .execute()
        )
    except Exception as e:
        logger.warning("ETF 비교 조회 실패 (%s): %s", ticker, e)
        return {"ticker": ticker, "comparisons": []}

    comparisons = []
    current_expense = None
    for peer in peers_result.data or []:
        is_current = peer["ticker"] == ticker.upper()
        if is_current:
            current_expense = peer.get("expense_ratio", 0) or 0
        comparisons.append(
            {
                "ticker": peer["ticker"],
                "name": peer.get("name", ""),
                "expense_ratio": peer.get("expense_ratio", 0),
                "is_current": is_current,
            }
        )

    # key_difference 생성 (보수율 비교 기반)
    for comp in comparisons:
        if comp["is_current"]:
            comp["key_difference"] = "현재 보유 ETF"
        elif current_expense is not None:
            diff = (comp.get("expense_ratio", 0) or 0) - current_expense
            if diff < 0:
                comp["key_difference"] = f"보수율 {abs(diff):.2f}%p 낮음"
            elif diff > 0:
                comp["key_difference"] = f"보수율 {diff:.2f}%p 높음"
            else:
                comp["key_difference"] = "보수율 동일"
        else:
            comp["key_difference"] = ""

    return {
        "ticker": ticker,
        "category": category,
        "comparisons": sorted(comparisons, key=lambda x: x.get("expense_ratio", 0)),
    }


# ──────────────────────────────────────────────
# 섹터 매핑 (ticker → sector)
# ──────────────────────────────────────────────

_COMPANY_SECTOR_MAP: dict[str, str] = {
    # 기술
    "AAPL": "기술",
    "MSFT": "기술",
    "NVDA": "기술",
    "AVGO": "기술",
    "GOOG": "기술",
    "GOOGL": "기술",
    "META": "기술",
    "TSLA": "기술",
    "AMD": "기술",
    "INTC": "기술",
    "QCOM": "기술",
    "TXN": "기술",
    "CRM": "기술",
    "ADBE": "기술",
    "ORCL": "기술",
    "CSCO": "기술",
    "AMAT": "기술",
    "LRCX": "기술",
    "KLAC": "기술",
    "MRVL": "기술",
    "MU": "기술",
    "SNPS": "기술",
    "CDNS": "기술",
    "PANW": "기술",
    "NOW": "기술",
    "PLTR": "기술",
    "CRWD": "기술",
    "NET": "기술",
    "MSTR": "기술",
    "COIN": "기술",
    "SQ": "기술",
    "SHOP": "기술",
    "SNOW": "기술",
    "DDOG": "기술",
    "ZS": "기술",
    "FTNT": "기술",
    "NFLX": "기술",
    "INTU": "기술",
    "ISRG": "기술",
    "ANET": "기술",
    "ARM": "기술",
    "ASML": "기술",
    "TSM": "기술",
    "SMCI": "기술",
    "DELL": "기술",
    "HPE": "기술",
    "KEYS": "기술",
    "ON": "기술",
    "ADI": "기술",
    "NXPI": "기술",
    # 소비재
    "AMZN": "소비재(임의)",
    "COST": "소비재(필수)",
    "WMT": "소비재(필수)",
    "HD": "소비재(임의)",
    "NKE": "소비재(임의)",
    "SBUX": "소비재(임의)",
    "TGT": "소비재(임의)",
    "LOW": "소비재(임의)",
    "MCD": "소비재(임의)",
    "PG": "소비재(필수)",
    "KO": "소비재(필수)",
    "PEP": "소비재(필수)",
    "CL": "소비재(필수)",
    "MDLZ": "소비재(필수)",
    "PM": "소비재(필수)",
    "MO": "소비재(필수)",
    "EL": "소비재(임의)",
    "LULU": "소비재(임의)",
    "BKNG": "소비재(임의)",
    "ABNB": "소비재(임의)",
    "CMG": "소비재(임의)",
    "DPZ": "소비재(임의)",
    # 금융
    "JPM": "금융",
    "BAC": "금융",
    "WFC": "금융",
    "GS": "금융",
    "MS": "금융",
    "C": "금융",
    "BLK": "금융",
    "SCHW": "금융",
    "AXP": "금융",
    "V": "금융",
    "MA": "금융",
    "PYPL": "금융",
    "BRK.B": "금융",
    "BRK-B": "금융",
    "USB": "금융",
    "PNC": "금융",
    "TFC": "금융",
    "COF": "금융",
    "AIG": "금융",
    "MET": "금융",
    # 헬스케어
    "JNJ": "헬스케어",
    "UNH": "헬스케어",
    "PFE": "헬스케어",
    "MRK": "헬스케어",
    "ABBV": "헬스케어",
    "LLY": "헬스케어",
    "TMO": "헬스케어",
    "ABT": "헬스케어",
    "DHR": "헬스케어",
    "BMY": "헬스케어",
    "AMGN": "헬스케어",
    "GILD": "헬스케어",
    "VRTX": "헬스케어",
    "REGN": "헬스케어",
    "MRNA": "헬스케어",
    "BIIB": "헬스케어",
    "MDT": "헬스케어",
    "SYK": "헬스케어",
    "CI": "헬스케어",
    "ELV": "헬스케어",
    # 에너지
    "XOM": "에너지",
    "CVX": "에너지",
    "COP": "에너지",
    "SLB": "에너지",
    "EOG": "에너지",
    "MPC": "에너지",
    "PSX": "에너지",
    "VLO": "에너지",
    "OXY": "에너지",
    "HAL": "에너지",
    "DVN": "에너지",
    "FANG": "에너지",
    "PXD": "에너지",
    "HES": "에너지",
    "BKR": "에너지",
    # 산업재
    "BA": "산업재",
    "CAT": "산업재",
    "HON": "산업재",
    "UPS": "산업재",
    "RTX": "산업재",
    "LMT": "산업재",
    "GE": "산업재",
    "DE": "산업재",
    "MMM": "산업재",
    "UNP": "산업재",
    "FDX": "산업재",
    "WM": "산업재",
    "ETN": "산업재",
    "EMR": "산업재",
    "GD": "산업재",
    "NOC": "산업재",
    # 통신
    "T": "통신",
    "VZ": "통신",
    "TMUS": "통신",
    "CMCSA": "통신",
    "DIS": "통신",
    "CHTR": "통신",
    "NWSA": "통신",
    "PARA": "통신",
    # 유틸리티
    "NEE": "유틸리티",
    "DUK": "유틸리티",
    "SO": "유틸리티",
    "D": "유틸리티",
    "AEP": "유틸리티",
    "SRE": "유틸리티",
    "XEL": "유틸리티",
    "EXC": "유틸리티",
    # 부동산
    "AMT": "부동산",
    "PLD": "부동산",
    "CCI": "부동산",
    "EQIX": "부동산",
    "SPG": "부동산",
    "O": "부동산",
    "DLR": "부동산",
    "WELL": "부동산",
    # 소재
    "LIN": "소재",
    "APD": "소재",
    "SHW": "소재",
    "ECL": "소재",
    "NEM": "소재",
    "FCX": "소재",
    "DOW": "소재",
    "DD": "소재",
    # 귀금속/광업 (GDX 등)
    "NEM.US": "소재",
    "GOLD": "소재",
    "AEM": "소재",
    "FNV": "소재",
    "WPM": "소재",
    "RGLD": "소재",
}

# ──────────────────────────────────────────────
# Seed data loaders
# ──────────────────────────────────────────────

_SEEDS_DIR = Path(__file__).resolve().parent.parent / "seeds"


def _load_macro_sensitivity() -> dict[str, dict[str, str]]:
    """Load macro sensitivity ratings from seed JSON.

    Returns:
        Dict mapping ticker to {interest_rate, dollar, oil} sensitivity levels.
    """
    path = _SEEDS_DIR / "macro_sensitivity.json"
    if not path.exists():
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return {
            item["ticker"].upper(): {
                "interest_rate": item["interest_rate"],
                "dollar": item["dollar"],
                "oil": item["oil"],
            }
            for item in data
        }
    except Exception as e:
        logger.warning("매크로 민감도 시드 로드 실패: %s", e)
        return {}


def _load_comparison_groups() -> list[dict]:
    """Load pre-defined ETF comparison groups from seed JSON.

    Returns:
        List of comparison group dicts with group, tickers, summary.
    """
    path = _SEEDS_DIR / "etf_comparison_groups.json"
    if not path.exists():
        return []
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        logger.warning("비교 그룹 시드 로드 실패: %s", e)
        return []


def _load_etf_master() -> dict[str, dict]:
    """Load ETF master data (holdings, category, expense_ratio).

    Returns:
        Dict mapping ticker to full ETF data dict.
    """
    path = _SEEDS_DIR / "etf_master.json"
    if not path.exists():
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return {etf["ticker"].upper(): etf for etf in data if etf.get("ticker")}
    except Exception as e:
        logger.warning("ETF 마스터 시드 로드 실패: %s", e)
        return {}


_MACRO_SENSITIVITY = _load_macro_sensitivity()
_COMPARISON_GROUPS = _load_comparison_groups()
_ETF_MASTER = _load_etf_master()

# ──────────────────────────────────────────────
# Gemini API comparison cache
# ──────────────────────────────────────────────

_comparison_cache: dict[str, tuple[datetime, str]] = {}
_COMPARISON_CACHE_TTL = timedelta(hours=24)


def _cache_key_for_tickers(tickers: list[str]) -> str:
    """Generate a stable cache key for a set of tickers.

    Args:
        tickers: List of ETF ticker symbols.

    Returns:
        MD5-based cache key string.
    """
    normalized = sorted(t.upper() for t in tickers)
    raw = ",".join(normalized)
    return hashlib.md5(raw.encode(), usedforsecurity=False).hexdigest()  # nosec B324


# ──────────────────────────────────────────────
# Service class
# ──────────────────────────────────────────────


class EtfAnalysisService:
    """ETF 분석 서비스 — 섹터 집중도, 매크로 민감도, ETF 비교, 보유종목 변동."""

    async def get_sector_concentration(self, ticker: str) -> dict:
        """ETF 보유종목의 섹터별 분포를 계산한다.

        특정 섹터가 60% 이상이면 경고 배지를 생성한다.

        Args:
            ticker: ETF 티커 심볼.

        Returns:
            {sectors: [{name, weight_pct}], warning: str | None}
        """
        t = ticker.upper()
        holdings = _ETF_MASTER.get(t, {}).get("top_holdings", [])

        if not holdings:
            return {"sectors": [], "warning": None}

        # 섹터별 가중치 합산
        sector_weights: dict[str, float] = {}
        unmapped_weight = 0.0

        for h in holdings:
            h_ticker = h.get("ticker", "").upper()
            weight = float(h.get("weight", 0))
            sector = _COMPANY_SECTOR_MAP.get(h_ticker)
            if sector:
                sector_weights[sector] = sector_weights.get(sector, 0) + weight
            else:
                unmapped_weight += weight

        if unmapped_weight > 0:
            sector_weights["기타"] = sector_weights.get("기타", 0) + unmapped_weight

        # 정렬 후 반환
        sectors = sorted(
            [
                {"name": name, "weight_pct": round(w, 1)}
                for name, w in sector_weights.items()
            ],
            key=lambda x: x["weight_pct"],
            reverse=True,
        )

        # 경고 판단: 단일 섹터 60% 초과
        warning: str | None = None
        if sectors and sectors[0]["weight_pct"] > 60:
            warning = f"{sectors[0]['name']} 집중형"

        return {"sectors": sectors, "warning": warning}

    async def get_macro_sensitivity(self, ticker: str) -> dict:
        """ETF의 금리/달러/유가 민감도를 반환한다.

        Args:
            ticker: ETF 티커 심볼.

        Returns:
            {interest_rate: str, dollar: str, oil: str} 또는 미등록 ETF는 기본값.
        """
        t = ticker.upper()
        data = _MACRO_SENSITIVITY.get(t)
        if data:
            return data
        # 미등록 ETF: 기본 Medium
        return {"interest_rate": "Medium", "dollar": "Medium", "oil": "Medium"}

    async def compare_etfs(self, tickers: list[str]) -> dict:
        """2-3개 ETF의 구조적 차이를 3줄 한국어 요약으로 비교한다.

        Gemini API를 사용하여 비교 요약을 생성하며, 24시간 캐싱한다.
        Gemini API 사용 불가 시 시드 데이터의 사전 작성 비교문을 반환한다.

        Args:
            tickers: 비교할 ETF 티커 리스트 (2-3개).

        Returns:
            {tickers: list, summary: str, source: "gemini" | "seed" | "unavailable"}
        """
        normalized = [t.upper() for t in tickers]
        cache_key = _cache_key_for_tickers(normalized)

        # 캐시 확인
        now = datetime.now(timezone.utc)
        cached = _comparison_cache.get(cache_key)
        if cached and (now - cached[0]) < _COMPARISON_CACHE_TTL:
            return {"tickers": normalized, "summary": cached[1], "source": "cached"}

        # Gemini API 시도
        summary = await self._generate_gemini_comparison(normalized)
        if summary:
            _comparison_cache[cache_key] = (now, summary)
            return {"tickers": normalized, "summary": summary, "source": "gemini"}

        # Gemini 실패 시 시드 데이터에서 매칭
        seed_summary = self._find_seed_comparison(normalized)
        if seed_summary:
            _comparison_cache[cache_key] = (now, seed_summary)
            return {"tickers": normalized, "summary": seed_summary, "source": "seed"}

        return {
            "tickers": normalized,
            "summary": "비교 데이터를 생성할 수 없습니다. 잠시 후 다시 시도해주세요.",
            "source": "unavailable",
        }

    async def _generate_gemini_comparison(self, tickers: list[str]) -> str | None:
        """Gemini API로 ETF 비교 요약을 생성한다.

        스레드 풀에서 실행하고 12초 타임아웃을 적용한다.

        Args:
            tickers: 비교할 ETF 티커 리스트.

        Returns:
            3줄 한국어 비교 요약 또는 실패 시 None.
        """
        import asyncio

        try:
            from google import genai
            from config import settings

            if not settings.GEMINI_API_KEY:
                logger.info("GEMINI_API_KEY 미설정, Gemini 비교 생략")
                return None

            # 각 ETF 정보 수집
            etf_infos = []
            for t in tickers:
                data = _ETF_MASTER.get(t, {})
                if data:
                    holdings_str = ", ".join(
                        f"{h.get('name', '')}({h.get('weight', 0)}%)"
                        for h in data.get("top_holdings", [])[:5]
                    )
                    etf_infos.append(
                        f"- {t}: {data.get('name_kr', data.get('name', ''))}, "
                        f"카테고리={data.get('category', 'N/A')}, "
                        f"보수율={data.get('expense_ratio', 'N/A')}%, "
                        f"상위5={holdings_str}"
                    )

            if not etf_infos:
                return None

            prompt = (
                "다음 ETF들의 구조적 차이를 한국어 3줄로 요약해줘. "
                "투자자가 어떤 상황에서 어떤 ETF를 선택해야 하는지 명확하게.\n\n"
                + "\n".join(etf_infos)
                + "\n\n규칙: 정확히 3문장, 각 문장은 한 줄, 전문 용어는 최소화."
            )

            def _call_sync() -> str:
                client = genai.Client(api_key=settings.GEMINI_API_KEY)
                response = client.models.generate_content(
                    model=settings.GEMINI_MODEL,
                    contents=prompt,
                )
                return (response.text or "").strip()

            text = await asyncio.wait_for(
                asyncio.to_thread(_call_sync),
                timeout=12,
            )
            return text

        except asyncio.TimeoutError:
            logger.warning("Gemini ETF 비교 타임아웃 (12s)")
            return None
        except Exception as e:
            logger.warning("Gemini ETF 비교 생성 실패: %s", e)
            return None

    def _find_seed_comparison(self, tickers: list[str]) -> str | None:
        """시드 데이터에서 매칭되는 비교 그룹을 찾는다.

        입력 티커들이 특정 비교 그룹의 부분집합이면 해당 summary를 반환한다.
        정확 매칭이 없으면 교집합이 가장 큰 그룹을 반환한다.
        시드에도 없으면 ETF 마스터 데이터로 동적 비교 요약을 생성한다.

        Args:
            tickers: 비교할 ETF 티커 리스트.

        Returns:
            매칭된 비교 요약 또는 None.
        """
        ticker_set = set(tickers)

        # 1) 정확 매칭 (기존 로직)
        for group in _COMPARISON_GROUPS:
            group_set = set(t.upper() for t in group.get("tickers", []))
            if ticker_set.issubset(group_set):
                return group.get("summary")

        # 2) 교집합 기반 부분 매칭 (2개 이상 겹치면 사용)
        best_group = None
        best_overlap = 0
        for group in _COMPARISON_GROUPS:
            group_set = set(t.upper() for t in group.get("tickers", []))
            overlap = len(ticker_set & group_set)
            if overlap > best_overlap:
                best_overlap = overlap
                best_group = group
        if best_overlap >= 2 and best_group:
            return best_group.get("summary")

        # 3) ETF 마스터 데이터로 동적 비교 생성
        return self._build_dynamic_comparison(tickers)

    def _build_dynamic_comparison(self, tickers: list[str]) -> str | None:
        """ETF 마스터 시드 데이터로 동적 비교 요약을 생성한다.

        Args:
            tickers: 비교할 ETF 티커 리스트.

        Returns:
            비교 요약 문자열 또는 None.
        """
        infos = []
        for t in tickers:
            data = _ETF_MASTER.get(t)
            if not data:
                return None
            name = data.get("name_kr") or data.get("name", t)
            category = data.get("category", "N/A")
            expense = data.get("expense_ratio", "N/A")
            top3 = ", ".join(
                h.get("name", "") for h in data.get("top_holdings", [])[:3]
            )
            infos.append(
                f"{t}({name}): 카테고리={category}, 보수율={expense}%, 상위종목={top3}"
            )

        lines = " | ".join(infos)
        return f"ETF 비교: {lines}"

    async def get_holdings_changes(self, ticker: str) -> list[dict]:
        """주간 보유종목 비중 변동을 반환한다.

        현재 holdings와 7일 전 스냅샷을 비교하여 1% 이상 변동 항목만 반환.
        스냅샷이 없으면 빈 리스트를 반환한다.

        Args:
            ticker: ETF 티커 심볼.

        Returns:
            [{name, ticker, current_weight, previous_weight, change_pct}] 리스트.
        """
        t = ticker.upper()
        try:
            from services.supabase_client import get_supabase

            sb = get_supabase()

            # 7일 전 날짜
            cutoff = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()

            resp = (
                sb.table("holdings_snapshots")
                .select("holdings")
                .eq("ticker", t)
                .gte("snapshot_date", cutoff)
                .order("snapshot_date", desc=True)
                .limit(1)
                .execute()
            )

            if not resp.data:
                return []

            old_holdings: list[dict] = resp.data[0].get("holdings", [])
        except Exception as e:
            logger.info("보유종목 스냅샷 조회 불가 (%s): %s", t, e)
            return []

        # 현재 holdings
        current_holdings = _ETF_MASTER.get(t, {}).get("top_holdings", [])
        if not current_holdings:
            return []

        # 이전 보유종목 맵 생성
        old_map: dict[str, float] = {}
        for h in old_holdings:
            h_ticker = h.get("ticker", "").upper()
            if h_ticker:
                old_map[h_ticker] = float(h.get("weight", 0))

        # 변동 계산 (1% 이상만)
        changes: list[dict] = []
        for h in current_holdings:
            h_ticker = h.get("ticker", "").upper()
            current_weight = float(h.get("weight", 0))
            previous_weight = old_map.get(h_ticker, 0.0)
            change = current_weight - previous_weight

            if abs(change) >= 1.0:
                changes.append(
                    {
                        "name": h.get("name", ""),
                        "ticker": h_ticker,
                        "current_weight": round(current_weight, 2),
                        "previous_weight": round(previous_weight, 2),
                        "change_pct": round(change, 2),
                    }
                )

        # 변동폭 큰 순서로 정렬
        changes.sort(key=lambda x: abs(x["change_pct"]), reverse=True)
        return changes

    async def get_combined_analysis(self, ticker: str) -> dict:
        """섹터 집중도 + 매크로 민감도 + 보유종목 변동을 통합 반환한다.

        Results are cached for 15 minutes to reduce repeated computation.

        Args:
            ticker: ETF 티커 심볼.

        Returns:
            {ticker, sector_concentration, macro_sensitivity, holdings_changes}
        """
        from services.cache import get_cached, set_cached

        t = ticker.upper()
        cache_key = f"etf_analysis_{t}"
        cached = get_cached(cache_key)
        if cached is not None:
            logger.debug("Cache hit for %s", cache_key)
            return cached

        sector = await self.get_sector_concentration(t)
        macro = await self.get_macro_sensitivity(t)
        changes = await self.get_holdings_changes(t)

        result = {
            "ticker": t,
            "sector_concentration": sector,
            "macro_sensitivity": macro,
            "holdings_changes": changes,
        }
        set_cached(cache_key, result)
        return result


etf_analysis_service = EtfAnalysisService()
