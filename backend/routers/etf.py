"""ETF router — ETF search, details, popular, price, analysis, and device registration."""

from fastapi import APIRouter, Query, Path, HTTPException
from pydantic import BaseModel, Field

from models.schemas import DeviceRegisterRequest, ETFRegisterRequest
from services.etf_service import etf_service
from services.etf_analysis_service import etf_analysis_service


class BatchPriceRequest(BaseModel):
    """Request body for batch price lookup."""
    tickers: list[str] = Field(..., min_length=1, max_length=30, description="ETF 티커 리스트")

router = APIRouter()


@router.post("/register")
async def register_etfs(request: ETFRegisterRequest) -> dict:
    """Register ETFs to a device's watchlist."""
    registered = await etf_service.register_etfs(request.device_id, request.tickers)
    return {"device_id": request.device_id, "registered": registered, "total": len(registered)}


@router.get("/search")
async def search_etfs(
    q: str = Query(..., min_length=1, description="Search query (ticker, name, or category)"),
    limit: int = Query(20, ge=1, le=50, description="Number of results"),
) -> dict:
    """Search ETFs by name, ticker, or category."""
    results = await etf_service.search(q, limit)
    return {"results": [r.model_dump() for r in results], "total": len(results)}


@router.get("/popular")
async def get_popular_etfs() -> dict:
    """Get top 10 popular ETFs."""
    results = await etf_service.get_popular()
    return {"etfs": [r.model_dump() for r in results], "total": len(results)}


@router.get("/trending")
async def get_trending_etfs() -> dict:
    """Get trending ETFs (alias for /popular)."""
    return await get_popular_etfs()


@router.get("/compare")
async def compare_etfs(
    tickers: str = Query(..., description="Comma-separated ETF tickers (2-3)"),
) -> dict:
    """ETF 비교 — 구조적 차이를 3줄 한국어로 요약.

    Args:
        tickers: 쉼표로 구분된 ETF 티커 (예: QQQ,QQQM,TQQQ).

    Returns:
        비교 요약 결과.
    """
    ticker_list = [t.strip().upper() for t in tickers.split(",") if t.strip()]
    if len(ticker_list) < 2 or len(ticker_list) > 3:
        raise HTTPException(
            status_code=400,
            detail="2~3개의 ETF 티커를 입력해주세요 (예: QQQ,QQQM,TQQQ)",
        )
    result = await etf_analysis_service.compare_etfs(ticker_list)
    return result


@router.get("/{ticker}/detail")
async def get_etf_detail(
    ticker: str = Path(..., description="ETF ticker symbol"),
) -> dict:
    """Get detailed information about a specific ETF."""
    detail = await etf_service.get_detail(ticker)
    if detail is None:
        raise HTTPException(status_code=404, detail=f"ETF '{ticker.upper()}' not found")
    return detail.model_dump()


@router.post("/batch-prices")
async def get_batch_prices(request: BatchPriceRequest) -> dict:
    """여러 ETF의 현재가를 일괄 조회한다.

    Args:
        request: 티커 리스트가 담긴 요청 본문.

    Returns:
        티커를 키로, 가격 정보를 값으로 하는 딕셔너리.
    """
    from services.price_service import get_batch_prices

    tickers = [t.strip().upper() for t in request.tickers if t.strip()]
    if not tickers:
        raise HTTPException(status_code=400, detail="티커를 하나 이상 입력해주세요")

    results = await get_batch_prices(tickers)
    # Convert list to dict keyed by ticker
    prices = {item["ticker"]: item for item in results}
    return {"prices": prices, "updated_at": _utc_now_iso()}


def _utc_now_iso() -> str:
    """현재 UTC 시각을 ISO 8601 문자열로 반환한다."""
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat()


@router.get("/{ticker}/price")
async def get_price(ticker: str) -> dict:
    """ETF 현재가 및 등락률."""
    from services.price_service import get_etf_price
    price_data = await get_etf_price(ticker.upper())
    return price_data


@router.get("/{ticker}/holdings")
async def get_holdings(ticker: str) -> dict:
    """Get ETF holdings/constituents."""
    from services.holdings_service import holdings_service
    result = await holdings_service.get_holdings(ticker)
    return result


@router.get("/{ticker}/analysis")
async def get_etf_analysis(
    ticker: str = Path(..., description="ETF ticker symbol"),
) -> dict:
    """ETF 통합 분석 — 섹터 집중도 + 매크로 민감도 + 보유종목 변동.

    Args:
        ticker: ETF 티커 심볼.

    Returns:
        통합 분석 결과.
    """
    result = await etf_analysis_service.get_combined_analysis(ticker)
    return result


@router.get("/{ticker}/holdings-changes")
async def get_holdings_changes(
    ticker: str = Path(..., description="ETF ticker symbol"),
) -> dict:
    """주간 보유종목 비중 변동.

    Args:
        ticker: ETF 티커 심볼.

    Returns:
        1% 이상 변동된 보유종목 리스트.
    """
    changes = await etf_analysis_service.get_holdings_changes(ticker)
    return {"ticker": ticker.upper(), "changes": changes, "total": len(changes)}


@router.post("/devices/register")
async def register_device(request: DeviceRegisterRequest) -> dict:
    """디바이스 + 푸시 토큰 등록."""
    from services.push_service import register_token
    success = register_token(request.device_id, request.push_token)
    return {"success": success}
