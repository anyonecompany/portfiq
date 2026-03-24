"""Supabase 시그널 파이프라인 기반 피드 서비스.

Edge Function이 적재한 시그널 데이터를 기존 FeedItem 스키마로 변환하여 반환한다.
Supabase 조회 실패 시 빈 리스트를 반환하며 절대 예외를 상위로 전파하지 않는다.
"""

from __future__ import annotations

import logging
from typing import Any

from models.schemas import FeedItem, ETFImpact

logger = logging.getLogger(__name__)


def _magnitude_to_level(magnitude: float | None) -> str:
    """impact_magnitude(0~1 float) → "High"/"Medium"/"Low" 변환.

    Args:
        magnitude: 0~1 범위의 영향도 수치.

    Returns:
        "High", "Medium", or "Low".
    """
    if magnitude is None:
        return "Low"
    if magnitude >= 0.7:
        return "High"
    if magnitude >= 0.4:
        return "Medium"
    return "Low"


def _sentiment_to_korean(sentiment: str | None) -> str:
    """영문 sentiment → 한국어 변환.

    Args:
        sentiment: "positive", "negative", "neutral" 등.

    Returns:
        "호재", "위험", or "중립".
    """
    mapping = {
        "positive": "호재",
        "negative": "위험",
        "neutral": "중립",
    }
    return mapping.get((sentiment or "").lower(), "중립")


def _build_feed_item(
    article: dict[str, Any],
    translation: dict[str, Any] | None,
    classification: dict[str, Any] | None,
    signals: list[dict[str, Any]],
) -> FeedItem:
    """Supabase 조회 결과를 기존 FeedItem 스키마로 변환한다.

    Args:
        article: news_articles 행.
        translation: article_translations 행 (없을 수 있음).
        classification: news_classifications 행 (없을 수 있음).
        signals: 해당 기사의 news_etf_signals 행 리스트.

    Returns:
        기존 앱과 호환되는 FeedItem.
    """
    # headline: 번역 제목 우선, 없으면 원문
    headline = article.get("title", "")
    if translation:
        headline = translation.get("translated_title") or headline

    # impact_reason: 시그널 텍스트 또는 번역 본문
    impact_reason = ""
    if signals:
        impact_reason = signals[0].get("signal_text", "")
    if not impact_reason and translation:
        impact_reason = translation.get("translated_content", "")

    # summary_3line: 번역 요약
    summary_3line = ""
    if translation:
        summary_3line = translation.get("translated_summary", "")

    # sentiment: classification 우선, 없으면 시그널의 impact_direction fallback
    sentiment = "중립"
    if classification:
        sentiment = _sentiment_to_korean(classification.get("sentiment"))
    if sentiment == "중립" and signals:
        direction = signals[0].get("impact_direction", "")
        if direction:
            sentiment = _sentiment_to_korean(direction)

    # impacts: 각 시그널 → ETFImpact
    impacts = [
        ETFImpact(
            etf_ticker=sig.get("etf_code", ""),
            level=_magnitude_to_level(sig.get("impact_magnitude")),
        )
        for sig in signals
        if sig.get("etf_code")
    ]

    return FeedItem(
        id=str(article.get("id", "")),
        headline=headline,
        impact_reason=impact_reason,
        summary_3line=summary_3line,
        sentiment=sentiment,
        source=article.get("source"),
        source_url=article.get("url"),
        published_at=article.get("published_at"),
        impacts=impacts,
        is_mock=False,
    )


async def get_signal_feed(
    device_id: str,
    offset: int = 0,
    limit: int = 20,
) -> list[FeedItem]:
    """device_id 기반 개인화 시그널 피드를 반환한다.

    Supabase에서 user_signal_feeds → news_etf_signals → news_articles +
    article_translations + news_classifications를 조회하여 FeedItem으로 변환한다.

    Args:
        device_id: 디바이스 식별자.
        offset: 페이지네이션 시작 위치.
        limit: 반환할 최대 아이템 수.

    Returns:
        FeedItem 리스트. Supabase 오류 시 빈 리스트.
    """
    try:
        from services.supabase_client import get_supabase_service

        sb = get_supabase_service()
    except Exception as e:
        logger.warning("Supabase 클라이언트 초기화 실패: %s", e)
        return []

    try:
        # 1. 해당 디바이스의 시그널 피드 조회 (최신순)
        feed_resp = (
            sb.table("user_signal_feeds")
            .select("signal_id, is_read, created_at")
            .eq("device_id", device_id)
            .order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )

        feed_rows = feed_resp.data or []
        if not feed_rows:
            return []

        signal_ids = [row["signal_id"] for row in feed_rows]

        # 2. 시그널 상세 조회
        signals_resp = (
            sb.table("news_etf_signals")
            .select(
                "id, article_id, classification_id, etf_code, etf_name, "
                "impact_direction, impact_magnitude, signal_text"
            )
            .in_("id", signal_ids)
            .execute()
        )

        signals = signals_resp.data or []
        if not signals:
            return []

        # article_id별로 시그널 그룹핑
        article_ids: list[str] = []
        signals_by_article: dict[str, list[dict]] = {}
        for sig in signals:
            aid = sig["article_id"]
            if aid not in signals_by_article:
                article_ids.append(aid)
                signals_by_article[aid] = []
            signals_by_article[aid].append(sig)

        if not article_ids:
            return []

        # 3. 기사 원문 조회
        articles_resp = (
            sb.table("news_articles")
            .select("id, title, source, url, published_at")
            .in_("id", article_ids)
            .execute()
        )
        articles_map = {a["id"]: a for a in (articles_resp.data or [])}

        # 4. 번역 조회
        translations_resp = (
            sb.table("article_translations")
            .select(
                "article_id, translated_title, translated_content, translated_summary"
            )
            .in_("article_id", article_ids)
            .execute()
        )
        translations_map = {t["article_id"]: t for t in (translations_resp.data or [])}

        # 5. 분류 조회
        classification_ids = [
            sig["classification_id"] for sig in signals if sig.get("classification_id")
        ]
        classifications_map: dict[str, dict] = {}
        if classification_ids:
            cls_resp = (
                sb.table("news_classifications")
                .select("id, impact_level, sentiment")
                .in_("id", list(set(classification_ids)))
                .execute()
            )
            classifications_map = {c["id"]: c for c in (cls_resp.data or [])}

        # 6. FeedItem 조합 (signal_ids 순서 유지 = 시그널 피드 최신순)
        seen_articles: set[str] = set()
        items: list[FeedItem] = []

        for signal_id in signal_ids:
            # 해당 signal_id의 article_id 찾기
            matching_sig = next((s for s in signals if s["id"] == signal_id), None)
            if not matching_sig:
                continue

            aid = matching_sig["article_id"]
            if aid in seen_articles:
                continue
            seen_articles.add(aid)

            article = articles_map.get(aid)
            if not article:
                continue

            translation = translations_map.get(aid)
            cls_id = matching_sig.get("classification_id")
            classification = classifications_map.get(cls_id) if cls_id else None
            article_signals = signals_by_article.get(aid, [])

            items.append(
                _build_feed_item(article, translation, classification, article_signals)
            )

        # 7. impact 기반 정렬 (High → Medium → Low)
        level_order = {"High": 0, "Medium": 1, "Low": 2}
        items.sort(
            key=lambda item: min(
                (level_order.get(imp.level, 2) for imp in item.impacts),
                default=2,
            )
        )

        return items

    except Exception as e:
        logger.warning("시그널 피드 조회 실패 (fallback 사용): %s", e)
        return []


async def get_latest_signal_feed(
    offset: int = 0,
    limit: int = 20,
) -> tuple[list[FeedItem], int]:
    """전체 최신 시그널 피드 (개인화 없이).

    Args:
        offset: 페이지네이션 시작 위치.
        limit: 반환할 최대 아이템 수.

    Returns:
        (FeedItem 리스트, 전체 수) 튜플. 오류 시 (빈 리스트, 0).
    """
    try:
        from services.supabase_client import get_supabase_service

        sb = get_supabase_service()
    except Exception:
        return [], 0

    try:
        # 번역 완료 + 분류 완료된 최신 기사 조회
        articles_resp = (
            sb.table("news_articles")
            .select("id, title, source, url, published_at", count="exact")
            .eq("is_translated", True)
            .eq("is_classified", True)
            .order("published_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )

        articles = articles_resp.data or []
        total = articles_resp.count or len(articles)

        if not articles:
            return [], 0

        article_ids = [a["id"] for a in articles]

        # 번역 조회
        tr_resp = (
            sb.table("article_translations")
            .select(
                "article_id, translated_title, translated_content, translated_summary"
            )
            .in_("article_id", article_ids)
            .execute()
        )
        tr_map = {t["article_id"]: t for t in (tr_resp.data or [])}

        # 분류 조회
        cls_resp = (
            sb.table("news_classifications")
            .select("id, article_id, impact_level, sentiment")
            .in_("article_id", article_ids)
            .execute()
        )
        cls_map = {c["article_id"]: c for c in (cls_resp.data or [])}

        # 시그널 조회
        sig_resp = (
            sb.table("news_etf_signals")
            .select("article_id, etf_code, etf_name, impact_magnitude, signal_text")
            .in_("article_id", article_ids)
            .execute()
        )
        sig_by_article: dict[str, list[dict]] = {}
        for sig in sig_resp.data or []:
            aid = sig["article_id"]
            sig_by_article.setdefault(aid, []).append(sig)

        # FeedItem 조합
        items = []
        for article in articles:
            aid = article["id"]
            items.append(
                _build_feed_item(
                    article,
                    tr_map.get(aid),
                    cls_map.get(aid),
                    sig_by_article.get(aid, []),
                )
            )

        return items, total

    except Exception as e:
        logger.warning("최신 시그널 피드 조회 실패: %s", e)
        return [], 0
