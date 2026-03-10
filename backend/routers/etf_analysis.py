"""ETF 분석 API 라우터.

섹터 집중도, 거시경제 민감도(5변수), 동일 카테고리 ETF 비교를 제공한다.
"""

from fastapi import APIRouter

from services.etf_analysis_service import (
    get_sector_concentration,
    get_macro_sensitivity,
    get_etf_comparison,
)

router = APIRouter()


@router.get("/{ticker}/sector-concentration")
async def sector_concentration(ticker: str) -> dict:
    """ETF 섹터 집중도 분석.

    Args:
        ticker: ETF 티커 심볼.

    Returns:
        섹터별 비중 및 집중도 경고.
    """
    return await get_sector_concentration(ticker)


@router.get("/{ticker}/macro-sensitivity")
async def macro_sensitivity(ticker: str) -> dict:
    """ETF 거시경제 민감도 조회.

    Args:
        ticker: ETF 티커 심볼.

    Returns:
        금리/인플레이션/달러/유가/고용 5변수 민감도.
    """
    return await get_macro_sensitivity(ticker)


@router.get("/{ticker}/comparison")
async def etf_comparison(ticker: str) -> dict:
    """같은 카테고리 ETF 비교.

    Args:
        ticker: ETF 티커 심볼.

    Returns:
        동일 카테고리 ETF 리스트 (보수율 기준 정렬).
    """
    return await get_etf_comparison(ticker)
