"""캐시 TTL 상수 — API 비용 최적화의 핵심.

각 데이터 유형별 적절한 캐시 수명을 정의한다.
변동 빈도가 낮은 데이터일수록 긴 TTL을 적용하여 외부 API 호출을 최소화한다.
"""

from datetime import datetime
from zoneinfo import ZoneInfo


class CacheTTL:
    """데이터 유형별 TTL 상수 (초 단위)."""

    # ETF 메타데이터 (이름, 카테고리, 보수 — 거의 안 변함)
    ETF_META = 7 * 86400  # 7일

    # ETF 구성종목 (주 1회 갱신이면 충분)
    ETF_HOLDINGS = 7 * 86400  # 7일

    # ETF 비교 분석 (Gemini 생성 — 7일 캐시로 재호출 방지)
    ETF_COMPARISON = 7 * 86400  # 7일

    # 거시 민감도 (거의 안 변함)
    ETF_SENSITIVITY = 30 * 86400  # 30일

    # 가격 — 장중 vs 장외 분리
    ETF_PRICE_MARKET = 900  # 15분 (장중)
    ETF_PRICE_CLOSED = 6 * 3600  # 6시간 (장외/주말)

    # 뉴스
    NEWS_FEED = 600  # 10분
    NEWS_TRANSLATION = 30 * 86400  # 30일 (번역 결과는 안 변함)

    # 브리핑
    BRIEFING = 12 * 3600  # 12시간

    # 인기 ETF / 검색
    POPULAR_ETFS = 3600  # 1시간
    SEARCH_RESULT = 3600  # 1시간


def get_market_aware_price_ttl() -> int:
    """미국 시장 시간 기반 적응형 가격 TTL.

    장중(9:30~16:00 ET, 평일): 15분
    장외/주말: 6시간

    Returns:
        TTL in seconds.
    """
    try:
        now = datetime.now(ZoneInfo("US/Eastern"))
    except Exception:
        return CacheTTL.ETF_PRICE_MARKET  # fallback: 15분

    # 주말
    if now.weekday() >= 5:
        return CacheTTL.ETF_PRICE_CLOSED

    # 장중 (9:30 ~ 16:00 ET)
    market_open = now.replace(hour=9, minute=30, second=0, microsecond=0)
    market_close = now.replace(hour=16, minute=0, second=0, microsecond=0)

    if market_open <= now <= market_close:
        return CacheTTL.ETF_PRICE_MARKET

    return CacheTTL.ETF_PRICE_CLOSED
