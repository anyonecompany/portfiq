/**
 * 금융 용어 사전 — Gemini 번역 프롬프트에 주입.
 *
 * 한국 개인투자자가 자주 접하는 ETF/금융 용어의 영한 매핑.
 */

export const FINANCE_GLOSSARY: Record<string, string> = {
  "earnings beat": "실적 상회",
  "earnings miss": "실적 하회",
  "bull market": "강세장",
  "bear market": "약세장",
  "P/E ratio": "주가수익비율(PER)",
  "P/B ratio": "주가순자산비율(PBR)",
  "dividend yield": "배당수익률",
  "market cap": "시가총액",
  "AUM": "운용자산규모(AUM)",
  "expense ratio": "총보수비율",
  "NAV": "순자산가치(NAV)",
  "rebalancing": "리밸런싱",
  "inflows": "자금 유입",
  "outflows": "자금 유출",
  "tracking error": "추적오차",
  "yield curve": "수익률 곡선",
  "Fed rate": "미 연방기준금리",
  "hawkish": "매파적(긴축 성향)",
  "dovish": "비둘기파(완화 성향)",
  "tapering": "테이퍼링(자산매입 축소)",
  "CPI": "소비자물가지수(CPI)",
  "PCE": "개인소비지출(PCE)",
  "PPI": "생산자물가지수(PPI)",
  "guidance": "가이던스(실적 전망)",
  "short squeeze": "숏스퀴즈",
  "margin call": "마진콜",
  "volatility": "변동성",
  "overweight": "비중확대",
  "underweight": "비중축소",
  "sector rotation": "섹터 로테이션",
  "risk-on": "위험선호",
  "risk-off": "위험회피",
  "breakout": "돌파",
  "pullback": "조정(되돌림)",
  "consolidation": "횡보(보합)",
  "correction": "조정(하락)",
  "rally": "반등(랠리)",
  "sell-off": "매도세(급락)",
  "all-time high": "역대 최고가",
  "blue chip": "우량주",
  "large-cap": "대형주",
  "mid-cap": "중형주",
  "small-cap": "소형주",
};

/**
 * 용어 사전을 프롬프트용 문자열로 포매팅한다.
 */
export function glossaryToPromptBlock(): string {
  return Object.entries(FINANCE_GLOSSARY)
    .map(([en, ko]) => `- ${en} → ${ko}`)
    .join("\n");
}
