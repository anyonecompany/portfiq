"""영향도 분류 프롬프트."""

IMPACT_PROMPT = """당신은 금융 뉴스 분석가입니다. 아래 뉴스들이 각 ETF에 미치는 영향도와 방향을 분류하세요.

ETF 구성종목 정보:
{etf_holdings}

뉴스 목록:
{news_list}

아래 JSON 배열로 응답하세요:
[
  {{
    "news_index": 0,
    "impacts": [
      {{"ticker": "QQQ", "level": "High", "direction": "positive", "reason": "NVIDIA가 QQQ 8% 비중, 실적 호조"}}
    ]
  }}
]

규칙:
- level: "High" (구성종목 직접 언급), "Medium" (섹터 관련), "Low" (간접적)
- direction: 해당 ETF 가격에 미치는 영향 방향
  - "positive": 해당 ETF 상승 요인 (호재, 실적 호조, 금리 인하 등)
  - "negative": 해당 ETF 하락 요인 (악재, 규제 강화, 금리 인상 등)
  - "neutral": 방향성 불명확하거나 영향 제한적
- 같은 뉴스라도 ETF마다 direction이 다를 수 있음 (예: 금리 인상 → TLT negative, XLF positive)
- reason: 한국어, 20자 이내
- 관련 없는 ETF는 생략
"""
