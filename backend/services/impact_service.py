"""Impact analysis service — classifies news impact on ETFs via Gemini API + keyword fallback."""

from __future__ import annotations

import json
import logging

from google import genai

from config import settings
from models.schemas import ETFImpact
from prompts.impact import IMPACT_PROMPT

logger = logging.getLogger(__name__)

_GEMINI_MODEL = settings.GEMINI_MODEL
_gemini_client: genai.Client | None = None


def _get_gemini_client() -> genai.Client:
    """Return a lazily-initialised Gemini client."""
    global _gemini_client
    if _gemini_client is None:
        _gemini_client = genai.Client(api_key=settings.GEMINI_API_KEY)
    return _gemini_client


def _call_gemini(prompt: str) -> list | None:
    """Gemini API 호출 + JSON 배열 파싱.

    Args:
        prompt: The formatted prompt to send to Gemini.

    Returns:
        Parsed JSON list on success, None on failure.
    """
    try:
        client = _get_gemini_client()
        response = client.models.generate_content(
            model=_GEMINI_MODEL,
            contents=prompt,
        )
        text = response.text or ""
        if "```json" in text:
            text = text.split("```json")[1].split("```")[0]
        elif "```" in text:
            text = text.split("```")[1].split("```")[0]
        result = json.loads(text.strip())
        if isinstance(result, list):
            return result
        return None
    except Exception as e:
        logger.error("Gemini API 호출 실패: %s", e)
        return None


# ──────────────────────────────────────────────
# Keyword-to-ETF mapping for fallback classification
# ──────────────────────────────────────────────

_KEYWORD_ETF_MAP: dict[str, list[str]] = {
    # Tech / AI
    "nvidia": ["SOXL", "QQQ", "SOXX", "SMH", "XLK", "VGT"],
    "apple": ["QQQ", "VOO", "SPY", "VGT", "XLK", "FTEC"],
    "microsoft": ["QQQ", "VOO", "SPY", "VGT", "XLK", "FTEC"],
    "amazon": ["QQQ", "VOO", "SPY"],
    "meta": ["QQQ", "VOO"],
    "tesla": ["ARKK", "QQQ", "DRIV", "IDRV"],
    "ai": ["QQQ", "SOXL", "SOXX", "ARKK", "BOTZ", "SMH"],
    "semiconductor": ["SOXL", "SOXX", "SMH"],
    "반도체": ["SOXL", "SOXX", "SMH"],
    "기술주": ["QQQ", "VGT", "ARKK", "XLK", "FTEC"],
    "robot": ["BOTZ"],
    "로봇": ["BOTZ"],
    "cyber": ["HACK", "CIBR"],
    "사이버": ["HACK", "CIBR"],
    "cloud": ["SKYY", "WCLD"],
    "클라우드": ["SKYY", "WCLD"],
    "자율주행": ["DRIV", "IDRV"],
    "전기차": ["DRIV", "IDRV", "QCLN"],
    "ev": ["DRIV", "IDRV"],
    # Market / Macro
    "s&p": ["SPY", "VOO", "IVV", "SPLG"],
    "s&p 500": ["SPY", "VOO", "IVV", "SPLG"],
    "나스닥": ["QQQ", "TQQQ", "QQQM"],
    "nasdaq": ["QQQ", "TQQQ", "QQQM"],
    "다우": ["DIA"],
    "dow": ["DIA"],
    "러셀": ["IWM"],
    "russell": ["IWM"],
    "소형주": ["IWM"],
    "금리": ["TLT", "IEF", "QQQ", "ARKK"],
    "fomc": ["QQQ", "VOO", "SPY", "TLT", "IEF"],
    "연준": ["QQQ", "VOO", "SPY", "TLT", "IEF"],
    "인플레이션": ["TLT", "GLD", "VOO", "IEF"],
    "국채": ["TLT", "IEF"],
    "treasury": ["TLT", "IEF"],
    "채권": ["TLT", "IEF", "HYG", "LQD"],
    "bond": ["TLT", "IEF", "HYG", "LQD"],
    "하이일드": ["HYG"],
    "high yield": ["HYG"],
    # Commodities
    "유가": ["XLE", "AMLP"],
    "oil": ["XLE", "AMLP"],
    "금": ["GLD"],
    "gold": ["GLD"],
    "은": ["SLV"],
    "silver": ["SLV"],
    # Income
    "배당": ["SCHD", "JEPI", "JEPQ", "VIG", "DGRO", "DGRW", "DIVO", "QYLD"],
    "dividend": ["SCHD", "JEPI", "JEPQ", "VIG", "DGRO", "DGRW"],
    "커버드콜": ["JEPI", "JEPQ", "QYLD", "DIVO"],
    # China
    "중국": ["KWEB", "EEM", "MCHI", "FXI"],
    "china": ["KWEB", "EEM", "MCHI", "FXI"],
    # Emerging
    "신흥국": ["EEM", "VWO"],
    "emerging": ["EEM", "VWO"],
    "선진국": ["IEFA"],
    # Energy
    "에너지": ["XLE", "AMLP"],
    "energy": ["XLE", "AMLP"],
    "태양광": ["TAN", "QCLN", "ICLN"],
    "solar": ["TAN", "QCLN"],
    "클린에너지": ["ICLN", "QCLN"],
    "clean energy": ["ICLN", "QCLN"],
    # Healthcare
    "헬스케어": ["XLV"],
    "healthcare": ["XLV"],
    "제약": ["XLV"],
    # Finance
    "금융": ["XLF"],
    "은행": ["XLF"],
    "bank": ["XLF"],
    # Real estate
    "부동산": ["VNQ"],
    "리츠": ["VNQ"],
    "reit": ["VNQ"],
    # Crypto
    "비트코인": ["IBIT", "BITO"],
    "bitcoin": ["IBIT", "BITO"],
    "crypto": ["IBIT", "BITO"],
    "암호화폐": ["IBIT", "BITO"],
}

_LEVEL_THRESHOLDS = {"high": 2, "medium": 1, "low": 0}

# 키워드 기반 direction fallback
_POSITIVE_KEYWORDS = [
    "상승",
    "호조",
    "성장",
    "급등",
    "반등",
    "최고",
    "호재",
    "수혜",
    "surge",
    "rally",
    "gain",
    "rise",
    "jump",
    "soar",
    "record high",
    "beat",
    "exceed",
    "outperform",
    "bullish",
    "upgrade",
]
_NEGATIVE_KEYWORDS = [
    "하락",
    "급락",
    "폭락",
    "악재",
    "위기",
    "손실",
    "둔화",
    "우려",
    "리스크",
    "제재",
    "규제",
    "관세",
    "파산",
    "디폴트",
    "drop",
    "fall",
    "plunge",
    "crash",
    "decline",
    "loss",
    "risk",
    "tariff",
    "sanction",
    "downgrade",
    "bearish",
    "recession",
    "layoff",
]


def _keyword_direction(text: str) -> str:
    """Classify direction from headline keywords.

    Args:
        text: News headline text.

    Returns:
        "positive", "negative", or "neutral".
    """
    text_lower = text.lower()
    pos = sum(1 for kw in _POSITIVE_KEYWORDS if kw in text_lower)
    neg = sum(1 for kw in _NEGATIVE_KEYWORDS if kw in text_lower)
    if pos > neg:
        return "positive"
    if neg > pos:
        return "negative"
    return "neutral"


def _keyword_classify(
    text: str, target_tickers: list[str] | None = None
) -> list[ETFImpact]:
    """Keyword-based fallback classification.

    Args:
        text: The news headline or body to analyse.
        target_tickers: If provided, only return impacts for these tickers.

    Returns:
        List of ETFImpact objects with level assigned.
    """
    text_lower = text.lower()
    ticker_scores: dict[str, int] = {}

    for keyword, etfs in _KEYWORD_ETF_MAP.items():
        if keyword in text_lower:
            for etf in etfs:
                ticker_scores[etf] = ticker_scores.get(etf, 0) + 1

    results: list[ETFImpact] = []
    for ticker, score in sorted(
        ticker_scores.items(), key=lambda x: x[1], reverse=True
    ):
        if target_tickers and ticker not in target_tickers:
            continue
        if score >= _LEVEL_THRESHOLDS["high"]:
            level = "High"
        elif score >= _LEVEL_THRESHOLDS["medium"]:
            level = "Medium"
        else:
            level = "Low"
        results.append(ETFImpact(etf_ticker=ticker, level=level))

    return results


class ImpactService:
    """Classifies news impact on ETFs via Gemini API with keyword fallback."""

    def classify(
        self, text: str, target_tickers: list[str] | None = None
    ) -> list[ETFImpact]:
        """Classify the impact of a piece of text on ETFs.

        Uses keyword-based classification (synchronous). For Gemini API
        classification, use batch_analyze().

        Args:
            text: The news headline or body to analyse.
            target_tickers: If provided, only return impacts for these tickers.

        Returns:
            List of ETFImpact objects with level assigned.
        """
        return _keyword_classify(text, target_tickers)

    async def analyze_impact(self, article: dict, ticker: str) -> dict:
        """Analyse how a news article impacts a specific ETF.

        Args:
            article: Dict with "headline" or "title" key.
            ticker: ETF ticker to evaluate impact for.

        Returns:
            Dict with impact_score, direction, affected_holdings, and reasoning.
        """
        headline = article.get("headline", "") or article.get("title", "")
        impacts = self.classify(headline, target_tickers=[ticker.upper()])
        if impacts:
            level = impacts[0].level
            score = {"High": 0.9, "Medium": 0.5, "Low": 0.2}[level]
        else:
            level = "Low"
            score = 0.0

        direction = _keyword_direction(headline)
        return {
            "impact_score": score,
            "direction": direction,
            "affected_holdings": [],
            "reasoning": f"Keyword-based classification: {level} impact on {ticker}",
        }

    async def batch_analyze(
        self, articles: list[dict], tickers: list[str]
    ) -> list[dict]:
        """Analyse impact of multiple articles on multiple ETFs using Gemini API.

        Sends articles in batches of 10 to Gemini for classification.
        Falls back to keyword-based classification on API failure.

        Args:
            articles: List of article dicts with "headline" or "title" key.
            tickers: List of ETF tickers to evaluate.

        Returns:
            List of dicts with article_id, ticker, impact_score, direction,
            affected_holdings, and reasoning.
        """
        if not settings.GEMINI_API_KEY:
            logger.warning("GEMINI_API_KEY 미설정 — keyword fallback 사용")
            return await self._batch_analyze_keyword(articles, tickers)

        results: list[dict] = []
        batch_size = 10

        for i in range(0, len(articles), batch_size):
            batch = articles[i : i + batch_size]
            batch_results = await self._batch_analyze_gemini(batch, tickers)
            if batch_results is None:
                # Fallback to keyword for this batch
                batch_results = await self._batch_analyze_keyword(batch, tickers)
            results.extend(batch_results)

        return results

    async def _batch_analyze_gemini(
        self, articles: list[dict], tickers: list[str]
    ) -> list[dict] | None:
        """Send a batch of articles to Gemini for impact classification.

        Args:
            articles: Batch of article dicts (max 10).
            tickers: ETF tickers to evaluate.

        Returns:
            List of result dicts, or None on failure.
        """
        import asyncio

        # Build news list text
        news_lines: list[str] = []
        for idx, article in enumerate(articles):
            headline = article.get("headline", "") or article.get("title", "")
            news_lines.append(f"[{idx}] {headline}")
        news_list = "\n".join(news_lines)

        # Build ETF holdings text (simplified)
        etf_holdings = ", ".join(tickers)

        prompt = IMPACT_PROMPT.format(etf_holdings=etf_holdings, news_list=news_list)
        gemini_results = await asyncio.to_thread(_call_gemini, prompt)

        if gemini_results is None:
            return None

        # Parse Gemini response into result dicts
        results: list[dict] = []
        impact_map: dict[int, list[dict]] = {}
        for item in gemini_results:
            news_idx = item.get("news_index", 0)
            impacts = item.get("impacts", [])
            impact_map[news_idx] = impacts

        for idx, article in enumerate(articles):
            article_id = article.get("id", f"unknown-{idx}")
            ai_impacts = impact_map.get(idx, [])

            if ai_impacts:
                for imp in ai_impacts:
                    ticker = imp.get("ticker", "")
                    level = imp.get("level", "Low")
                    direction = imp.get("direction", "neutral")
                    reason = imp.get("reason", "")
                    score = {"High": 0.9, "Medium": 0.5, "Low": 0.2}.get(level, 0.1)
                    results.append(
                        {
                            "article_id": article_id,
                            "ticker": ticker,
                            "impact_score": score,
                            "direction": direction,
                            "affected_holdings": [],
                            "reasoning": f"Gemini 분류: {reason}",
                        }
                    )
            else:
                for ticker in tickers:
                    results.append(
                        {
                            "article_id": article_id,
                            "ticker": ticker,
                            "impact_score": 0.0,
                            "direction": "neutral",
                            "affected_holdings": [],
                            "reasoning": "Gemini 분류: 관련 없음",
                        }
                    )

        return results

    async def _batch_analyze_keyword(
        self, articles: list[dict], tickers: list[str]
    ) -> list[dict]:
        """Keyword fallback for batch analysis.

        Args:
            articles: List of article dicts.
            tickers: ETF tickers to evaluate.

        Returns:
            List of result dicts using keyword classification.
        """
        results: list[dict] = []
        for article in articles:
            for ticker in tickers:
                result = await self.analyze_impact(article, ticker)
                result["article_id"] = article.get("id", "unknown")
                result["ticker"] = ticker
                results.append(result)
        return results


impact_service = ImpactService()
