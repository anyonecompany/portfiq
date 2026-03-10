"""영향도 분류 프롬프트."""

IMPACT_PROMPT = """당신은 금융 뉴스 분석가입니다. 아래 뉴스들이 각 ETF에 미치는 영향도를 분류하세요.

ETF 구성종목 정보:
{etf_holdings}

뉴스 목록:
{news_list}

아래 JSON 배열로 응답하세요:
[
  {{
    "news_index": 0,
    "impacts": [
      {{"ticker": "QQQ", "level": "High", "reason": "NVIDIA가 QQQ 8% 비중, 직접 영향"}}
    ]
  }}
]

규칙:
- level: "High" (구성종목 직접 언급), "Medium" (섹터 관련), "Low" (간접적)
- reason: 한국어, 20자 이내
- 관련 없는 ETF는 생략
"""
