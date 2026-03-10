"""Holdings router — search ETFs by company stock."""

from fastapi import APIRouter, Query

router = APIRouter()


@router.get("/search")
async def search_by_company(
    company: str = Query(..., min_length=1, description="Company ticker to search for"),
) -> dict:
    """Find ETFs containing a specific company stock."""
    from services.holdings_service import holdings_service
    from services.etf_service import etf_service, _NAME_KR_MAP

    results = await holdings_service.search_by_company(company)
    # Enrich with ETF names
    for r in results:
        info = await etf_service.get_detail(r["etf_ticker"])
        if info:
            r["etf_name"] = info.name
            r["etf_name_kr"] = _NAME_KR_MAP.get(r["etf_ticker"].upper(), "")
    return {"company": company.upper(), "etfs": results}
