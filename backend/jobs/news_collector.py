"""뉴스 수집 Job — 15분 간격으로 실행."""

import logging

from services.news_service import fetch_and_store_news

logger = logging.getLogger(__name__)


async def collect_news() -> int:
    """뉴스 수집 1회 실행.

    Returns:
        수집된 뉴스 건수.
    """
    try:
        count = await fetch_and_store_news()
        logger.info("뉴스 수집 완료: %d건", count)
        return count
    except Exception as e:
        logger.error("뉴스 수집 실패: %s", e)
        return 0
