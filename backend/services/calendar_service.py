"""Economic calendar service — Finnhub API + recurring US macro event fallback.

Primary: Finnhub API로 실제 경제 이벤트 데이터를 가져온다.
Fallback: API 실패 시 규칙 기반 스케줄을 생성한다.
Caches results in memory with 1-hour TTL.

Usage:
    from services.calendar_service import calendar_service
    events = calendar_service.get_events(date(2026, 3, 1), date(2026, 3, 31))
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from enum import Enum

import httpx

from config import settings
from services.cache import get_cached, set_cached

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
# Models
# ──────────────────────────────────────────────

class ImpactLevel(str, Enum):
    """이벤트의 시장 영향도."""
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


@dataclass(frozen=True)
class CalendarEvent:
    """경제 캘린더 이벤트.

    Attributes:
        date: 이벤트 발표 날짜 (KST 기준).
        time: 한국 시간 기준 발표 시각 (HH:MM).
        name: 영문 이벤트명.
        name_ko: 한국어 이벤트명.
        impact_level: 시장 영향도 (high/medium/low).
        affected_tickers: 영향을 받는 ETF 티커 목록.
        description: 이벤트 상세 설명 (한국어).
    """
    date: date
    time: str
    name: str
    name_ko: str
    impact_level: ImpactLevel
    affected_tickers: list[str] = field(default_factory=list)
    description: str = ""

    def to_dict(self) -> dict:
        """Pydantic-free dict 변환."""
        return {
            "date": self.date.isoformat(),
            "time": self.time,
            "name": self.name,
            "name_ko": self.name_ko,
            "impact_level": self.impact_level.value,
            "affected_tickers": list(self.affected_tickers),
            "description": self.description,
        }


# ──────────────────────────────────────────────
# 반복 이벤트 정의 (Recurring Event Definitions)
# ──────────────────────────────────────────────

@dataclass(frozen=True)
class _RecurringEventDef:
    """반복 경제 이벤트 정의."""
    name: str
    name_ko: str
    impact_level: ImpactLevel
    affected_tickers: list[str]
    description: str
    time_kst: str  # 한국시간 발표 시각


# ── 주요 미국 경제 지표 반복 정의 ──

_CPI = _RecurringEventDef(
    name="CPI (Consumer Price Index)",
    name_ko="CPI (소비자물가지수)",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["TLT", "QQQ", "VOO", "SPY", "GLD", "IEF"],
    description="미국 소비자물가지수. 인플레이션 핵심 지표로 연준 금리 정책에 직접 영향.",
    time_kst="22:30",
)

_CORE_CPI = _RecurringEventDef(
    name="Core CPI (ex Food & Energy)",
    name_ko="근원 CPI (식품·에너지 제외)",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["TLT", "QQQ", "VOO", "SPY", "GLD"],
    description="식품·에너지 제외 소비자물가. 연준이 가장 주시하는 인플레이션 지표 중 하나.",
    time_kst="22:30",
)

_PPI = _RecurringEventDef(
    name="PPI (Producer Price Index)",
    name_ko="PPI (생산자물가지수)",
    impact_level=ImpactLevel.MEDIUM,
    affected_tickers=["TLT", "VOO", "SPY", "IEF"],
    description="생산자물가지수. CPI 선행지표로 인플레이션 방향성 파악에 활용.",
    time_kst="22:30",
)

_NFP = _RecurringEventDef(
    name="Nonfarm Payrolls (NFP)",
    name_ko="비농업 고용지표 (NFP)",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["SPY", "QQQ", "VOO", "TLT", "GLD", "DIA"],
    description="매월 첫째 금요일 발표. 미국 고용시장 건전성을 나타내는 최중요 지표.",
    time_kst="22:30",
)

_UNEMPLOYMENT_RATE = _RecurringEventDef(
    name="Unemployment Rate",
    name_ko="실업률",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["SPY", "QQQ", "VOO", "TLT", "DIA"],
    description="NFP와 동시 발표. 고용시장 전반의 건강 상태를 보여주는 핵심 지표.",
    time_kst="22:30",
)

_JOBLESS_CLAIMS = _RecurringEventDef(
    name="Initial Jobless Claims",
    name_ko="신규 실업수당 청구건수",
    impact_level=ImpactLevel.MEDIUM,
    affected_tickers=["SPY", "VOO", "DIA"],
    description="매주 목요일 발표. 고용시장 실시간 온도계.",
    time_kst="22:30",
)

_GDP = _RecurringEventDef(
    name="GDP (Gross Domestic Product)",
    name_ko="GDP (국내총생산)",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["SPY", "QQQ", "VOO", "DIA", "TLT", "IWM"],
    description="분기별 GDP 성장률. 미국 경제 전반의 성장세를 보여주는 핵심 지표.",
    time_kst="22:30",
)

_PCE = _RecurringEventDef(
    name="PCE Price Index",
    name_ko="PCE 물가지수",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["TLT", "GLD", "QQQ", "VOO", "SPY", "IEF"],
    description="연준이 가장 선호하는 인플레이션 지표. 매월 마지막 주 발표.",
    time_kst="22:30",
)

_CORE_PCE = _RecurringEventDef(
    name="Core PCE Price Index",
    name_ko="근원 PCE 물가지수",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["TLT", "GLD", "QQQ", "VOO", "SPY"],
    description="식품·에너지 제외 PCE. 연준의 2% 인플레이션 목표 기준 지표.",
    time_kst="22:30",
)

_ISM_MFG = _RecurringEventDef(
    name="ISM Manufacturing PMI",
    name_ko="ISM 제조업 PMI",
    impact_level=ImpactLevel.MEDIUM,
    affected_tickers=["SPY", "VOO", "DIA", "XLE", "IWM"],
    description="제조업 경기 확장/수축 지표. 50 이상이면 확장, 미만이면 수축.",
    time_kst="00:00",
)

_ISM_SVC = _RecurringEventDef(
    name="ISM Services PMI",
    name_ko="ISM 서비스업 PMI",
    impact_level=ImpactLevel.MEDIUM,
    affected_tickers=["SPY", "QQQ", "VOO", "DIA"],
    description="서비스업 경기 지표. 미국 GDP의 70% 이상을 차지하는 서비스업 동향.",
    time_kst="00:00",
)

_RETAIL_SALES = _RecurringEventDef(
    name="Retail Sales",
    name_ko="소매판매",
    impact_level=ImpactLevel.MEDIUM,
    affected_tickers=["SPY", "VOO", "DIA", "XLY"],
    description="미국 소비 지출 동향. GDP의 약 70%를 차지하는 소비 건전성 지표.",
    time_kst="22:30",
)

_CONSUMER_CONFIDENCE = _RecurringEventDef(
    name="Consumer Confidence Index",
    name_ko="소비자신뢰지수",
    impact_level=ImpactLevel.MEDIUM,
    affected_tickers=["SPY", "VOO", "DIA", "XLY"],
    description="소비자 경기 체감 지표. 향후 소비 지출 방향성 예측에 활용.",
    time_kst="00:00",
)

_MICHIGAN_SENTIMENT = _RecurringEventDef(
    name="Michigan Consumer Sentiment",
    name_ko="미시간대 소비자심리지수",
    impact_level=ImpactLevel.MEDIUM,
    affected_tickers=["SPY", "VOO", "DIA"],
    description="미시간대학 설문 기반 소비자 심리 지표. 인플레이션 기대치 포함.",
    time_kst="00:00",
)

_ADP_EMPLOYMENT = _RecurringEventDef(
    name="ADP Employment Change",
    name_ko="ADP 민간고용 변화",
    impact_level=ImpactLevel.MEDIUM,
    affected_tickers=["SPY", "VOO", "DIA", "QQQ"],
    description="NFP 2일 전 발표. 민간 부문 고용 동향 선행지표.",
    time_kst="22:15",
)

_DURABLE_GOODS = _RecurringEventDef(
    name="Durable Goods Orders",
    name_ko="내구재 주문",
    impact_level=ImpactLevel.MEDIUM,
    affected_tickers=["SPY", "DIA", "IWM", "XLI"],
    description="제조업 투자 심리 반영. 기업 설비투자 선행지표.",
    time_kst="22:30",
)

_HOUSING_STARTS = _RecurringEventDef(
    name="Housing Starts",
    name_ko="주택착공건수",
    impact_level=ImpactLevel.LOW,
    affected_tickers=["VNQ", "XHB", "ITB"],
    description="신규 주택 건설 시작 건수. 부동산 시장 및 경기 체감 지표.",
    time_kst="22:30",
)

_EXISTING_HOME_SALES = _RecurringEventDef(
    name="Existing Home Sales",
    name_ko="기존주택매매",
    impact_level=ImpactLevel.LOW,
    affected_tickers=["VNQ", "XHB"],
    description="기존 주택 거래 건수. 부동산 시장 건전성 지표.",
    time_kst="00:00",
)


# ──────────────────────────────────────────────
# FOMC 일정 (연 8회, 2일간 회의 → 둘째 날 결정 발표)
# 2026년 FOMC 일정 (예상)
# ──────────────────────────────────────────────

_FOMC_2025_DATES: list[date] = [
    date(2025, 1, 29), date(2025, 3, 19), date(2025, 5, 7),
    date(2025, 6, 18), date(2025, 7, 30), date(2025, 9, 17),
    date(2025, 10, 29), date(2025, 12, 17),
]

_FOMC_2026_DATES: list[date] = [
    date(2026, 1, 28), date(2026, 3, 18), date(2026, 4, 29),
    date(2026, 6, 17), date(2026, 7, 29), date(2026, 9, 16),
    date(2026, 10, 28), date(2026, 12, 16),
]

_FOMC_2027_DATES: list[date] = [
    date(2027, 1, 27), date(2027, 3, 17), date(2027, 4, 28),
    date(2027, 6, 16), date(2027, 7, 28), date(2027, 9, 15),
    date(2027, 10, 27), date(2027, 12, 15),
]

_ALL_FOMC_DATES: list[date] = _FOMC_2025_DATES + _FOMC_2026_DATES + _FOMC_2027_DATES

_FOMC_DEF = _RecurringEventDef(
    name="FOMC Rate Decision",
    name_ko="FOMC 금리 결정",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["QQQ", "SPY", "VOO", "TLT", "IEF", "GLD", "DIA", "ARKK"],
    description="연방공개시장위원회 금리 결정. 시장 전반에 가장 큰 영향을 미치는 이벤트.",
    time_kst="04:00",
)

_FOMC_MINUTES_DEF = _RecurringEventDef(
    name="FOMC Minutes",
    name_ko="FOMC 의사록 공개",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["QQQ", "SPY", "VOO", "TLT", "IEF", "GLD"],
    description="FOMC 회의 의사록. 위원들의 상세 토론 내용 및 경제 전망 포함.",
    time_kst="04:00",
)

_FED_SPEECH_DEF = _RecurringEventDef(
    name="Fed Chair Speech",
    name_ko="연준 의장 연설",
    impact_level=ImpactLevel.HIGH,
    affected_tickers=["QQQ", "SPY", "VOO", "TLT", "GLD"],
    description="연준 의장의 공개 발언. 금리 정책 방향에 대한 힌트 제공.",
    time_kst="",  # 시간 불규칙
)


# ──────────────────────────────────────────────
# 스케줄 생성 헬퍼 함수
# ──────────────────────────────────────────────

def _nth_weekday_of_month(year: int, month: int, weekday: int, n: int) -> date:
    """월의 n번째 특정 요일을 구한다.

    Args:
        year: 연도.
        month: 월 (1-12).
        weekday: 요일 (0=월요일, 4=금요일, 6=일요일).
        n: n번째 (1-based).

    Returns:
        해당 날짜.
    """
    first_day = date(year, month, 1)
    # 첫 번째 해당 요일 찾기
    days_ahead = weekday - first_day.weekday()
    if days_ahead < 0:
        days_ahead += 7
    first_occurrence = first_day + timedelta(days=days_ahead)
    return first_occurrence + timedelta(weeks=n - 1)


def _last_weekday_of_month(year: int, month: int, weekday: int) -> date:
    """월의 마지막 특정 요일을 구한다.

    Args:
        year: 연도.
        month: 월 (1-12).
        weekday: 요일 (0=월요일).

    Returns:
        해당 날짜.
    """
    # 다음 달 1일에서 하루 빼서 마지막 날 구하기
    if month == 12:
        last_day = date(year + 1, 1, 1) - timedelta(days=1)
    else:
        last_day = date(year, month + 1, 1) - timedelta(days=1)

    days_back = (last_day.weekday() - weekday) % 7
    return last_day - timedelta(days=days_back)


def _approx_date_around(year: int, month: int, target_day: int) -> date:
    """target_day 근처의 비주말 날짜를 반환한다.

    Args:
        year: 연도.
        month: 월.
        target_day: 목표 일.

    Returns:
        주말이 아닌 가장 가까운 날짜.
    """
    # 월의 마지막 날 초과 방지
    if month == 12:
        max_day = (date(year + 1, 1, 1) - timedelta(days=1)).day
    else:
        max_day = (date(year, month + 1, 1) - timedelta(days=1)).day
    target_day = min(target_day, max_day)

    d = date(year, month, target_day)
    # 주말이면 다음 평일로
    if d.weekday() == 5:  # 토요일
        d += timedelta(days=2)
    elif d.weekday() == 6:  # 일요일
        d += timedelta(days=1)
    return d


# ──────────────────────────────────────────────
# 연간 이벤트 스케줄 생성
# ──────────────────────────────────────────────

def _generate_monthly_events(year: int, month: int) -> list[CalendarEvent]:
    """특정 월의 경제 이벤트 스케줄을 생성한다.

    주요 반복 이벤트의 일반적 발표 패턴을 기반으로 생성:
    - CPI: 매월 10~13일경
    - PPI: CPI 다음 날
    - NFP: 매월 첫째 금요일
    - PCE: 매월 마지막 주 금요일
    - ISM Manufacturing: 매월 1일 또는 첫 영업일
    - Jobless Claims: 매주 목요일
    - 기타: 대략적 날짜 기반

    Args:
        year: 연도.
        month: 월.

    Returns:
        해당 월의 CalendarEvent 리스트.
    """
    events: list[CalendarEvent] = []

    def _add(event_def: _RecurringEventDef, event_date: date) -> None:
        events.append(CalendarEvent(
            date=event_date,
            time=event_def.time_kst,
            name=event_def.name,
            name_ko=event_def.name_ko,
            impact_level=event_def.impact_level,
            affected_tickers=list(event_def.affected_tickers),
            description=event_def.description,
        ))

    # CPI — 매월 10~13일경 (보통 둘째 주 화~수)
    cpi_date = _approx_date_around(year, month, 12)
    _add(_CPI, cpi_date)
    _add(_CORE_CPI, cpi_date)

    # PPI — CPI 다음 날
    ppi_date = cpi_date + timedelta(days=1)
    if ppi_date.weekday() >= 5:  # 주말이면 월요일로
        ppi_date += timedelta(days=(7 - ppi_date.weekday()))
    _add(_PPI, ppi_date)

    # NFP + Unemployment Rate — 매월 첫째 금요일
    nfp_date = _nth_weekday_of_month(year, month, 4, 1)  # 4 = 금요일
    _add(_NFP, nfp_date)
    _add(_UNEMPLOYMENT_RATE, nfp_date)

    # ADP — NFP 2일 전 (수요일)
    adp_date = nfp_date - timedelta(days=2)
    _add(_ADP_EMPLOYMENT, adp_date)

    # PCE — 매월 마지막 주 금요일 근처
    pce_date = _last_weekday_of_month(year, month, 4)  # 마지막 금요일
    _add(_PCE, pce_date)
    _add(_CORE_PCE, pce_date)

    # ISM Manufacturing — 매월 1일 (또는 첫 영업일)
    ism_mfg_date = _approx_date_around(year, month, 1)
    _add(_ISM_MFG, ism_mfg_date)

    # ISM Services — ISM Manufacturing 2일 후
    ism_svc_date = ism_mfg_date + timedelta(days=2)
    if ism_svc_date.weekday() >= 5:
        ism_svc_date += timedelta(days=(7 - ism_svc_date.weekday()))
    _add(_ISM_SVC, ism_svc_date)

    # Retail Sales — 매월 15일 전후
    retail_date = _approx_date_around(year, month, 15)
    _add(_RETAIL_SALES, retail_date)

    # Consumer Confidence — 매월 마지막 화요일
    cc_date = _last_weekday_of_month(year, month, 1)  # 1 = 화요일
    _add(_CONSUMER_CONFIDENCE, cc_date)

    # Michigan Consumer Sentiment (preliminary) — 셋째 주 금요일
    michigan_date = _nth_weekday_of_month(year, month, 4, 2)  # 둘째 금요일 (예비치)
    _add(_MICHIGAN_SENTIMENT, michigan_date)

    # Durable Goods Orders — 매월 24~27일경
    durable_date = _approx_date_around(year, month, 25)
    _add(_DURABLE_GOODS, durable_date)

    # Housing Starts — 매월 17~19일경
    housing_date = _approx_date_around(year, month, 18)
    _add(_HOUSING_STARTS, housing_date)

    # GDP — 1, 4, 7, 10월에 발표 (전분기 실적)
    if month in (1, 4, 7, 10):
        gdp_date = _approx_date_around(year, month, 27)
        _add(_GDP, gdp_date)

    # Jobless Claims — 매주 목요일 (해당 월의 모든 목요일)
    first_thursday = _nth_weekday_of_month(year, month, 3, 1)  # 3 = 목요일
    thursday = first_thursday
    if month == 12:
        month_end = date(year + 1, 1, 1)
    else:
        month_end = date(year, month + 1, 1)

    while thursday < month_end:
        _add(_JOBLESS_CLAIMS, thursday)
        thursday += timedelta(weeks=1)

    return events


def _generate_fomc_events(from_date: date, to_date: date) -> list[CalendarEvent]:
    """FOMC 관련 이벤트 (금리 결정 + 의사록)를 생성한다.

    Args:
        from_date: 시작 날짜.
        to_date: 종료 날짜.

    Returns:
        기간 내 FOMC 관련 CalendarEvent 리스트.
    """
    events: list[CalendarEvent] = []

    for fomc_date in _ALL_FOMC_DATES:
        if from_date <= fomc_date <= to_date:
            events.append(CalendarEvent(
                date=fomc_date,
                time=_FOMC_DEF.time_kst,
                name=_FOMC_DEF.name,
                name_ko=_FOMC_DEF.name_ko,
                impact_level=_FOMC_DEF.impact_level,
                affected_tickers=list(_FOMC_DEF.affected_tickers),
                description=_FOMC_DEF.description,
            ))

        # 의사록은 FOMC 약 3주 후 발표
        minutes_date = fomc_date + timedelta(weeks=3)
        if minutes_date.weekday() >= 5:
            minutes_date += timedelta(days=(7 - minutes_date.weekday()))
        if from_date <= minutes_date <= to_date:
            events.append(CalendarEvent(
                date=minutes_date,
                time=_FOMC_MINUTES_DEF.time_kst,
                name=_FOMC_MINUTES_DEF.name,
                name_ko=_FOMC_MINUTES_DEF.name_ko,
                impact_level=_FOMC_MINUTES_DEF.impact_level,
                affected_tickers=list(_FOMC_MINUTES_DEF.affected_tickers),
                description=_FOMC_MINUTES_DEF.description,
            ))

    return events


# ──────────────────────────────────────────────
# CalendarService
# ──────────────────────────────────────────────

# ──────────────────────────────────────────────
# Finnhub 이벤트명 → 한국어 번역
# ──────────────────────────────────────────────

_EVENT_NAME_KO: dict[str, str] = {
    "CPI": "CPI (소비자물가지수)",
    "Core CPI": "근원 CPI",
    "PPI": "PPI (생산자물가지수)",
    "Core PPI": "근원 PPI",
    "Nonfarm Payrolls": "비농업 고용지표 (NFP)",
    "Non-Farm Payrolls": "비농업 고용지표 (NFP)",
    "Unemployment Rate": "실업률",
    "Initial Jobless Claims": "신규 실업수당 청구건수",
    "Continuing Jobless Claims": "계속 실업수당 청구건수",
    "GDP": "GDP (국내총생산)",
    "GDP Growth Rate": "GDP 성장률",
    "PCE Price Index": "PCE 물가지수",
    "Core PCE Price Index": "근원 PCE 물가지수",
    "ISM Manufacturing PMI": "ISM 제조업 PMI",
    "ISM Non-Manufacturing PMI": "ISM 서비스업 PMI",
    "ISM Services PMI": "ISM 서비스업 PMI",
    "Retail Sales": "소매판매",
    "Consumer Confidence": "소비자신뢰지수",
    "Michigan Consumer Sentiment": "미시간대 소비자심리지수",
    "ADP Employment Change": "ADP 민간고용 변화",
    "Durable Goods Orders": "내구재 주문",
    "Housing Starts": "주택착공건수",
    "Existing Home Sales": "기존주택매매",
    "New Home Sales": "신규주택매매",
    "FOMC": "FOMC 금리 결정",
    "Fed Interest Rate Decision": "연준 금리 결정",
    "FOMC Minutes": "FOMC 의사록 공개",
    "Fed Chair Press Conference": "연준 의장 기자회견",
    "Industrial Production": "산업생산",
    "Building Permits": "건축허가건수",
    "Trade Balance": "무역수지",
    "Consumer Spending": "소비자지출",
    "Personal Income": "개인소득",
    "Personal Spending": "개인지출",
    "Pending Home Sales": "주택판매보류",
    "Philadelphia Fed Manufacturing Index": "필라델피아 연은 제조업지수",
    "Empire State Manufacturing Index": "뉴욕 연은 제조업지수",
    "Chicago PMI": "시카고 PMI",
    "JOLTs Job Openings": "JOLTS 구인건수",
}


def _translate_event_name(name: str) -> str:
    """Finnhub 이벤트명을 한국어로 번역한다.

    정확한 매칭 → 부분 매칭 → 원문 반환 순서로 시도.

    Args:
        name: 영문 이벤트명.

    Returns:
        한국어 번역된 이벤트명.
    """
    # 정확한 매칭
    if name in _EVENT_NAME_KO:
        return _EVENT_NAME_KO[name]

    # 부분 매칭 (키워드가 이벤트명에 포함)
    name_lower = name.lower()
    for key, ko in _EVENT_NAME_KO.items():
        if key.lower() in name_lower:
            return ko

    return name  # 번역 없으면 원문


# ──────────────────────────────────────────────
# Finnhub 이벤트 → 영향 ETF 매핑
# ──────────────────────────────────────────────

_EVENT_ETF_MAP: dict[str, list[str]] = {
    "cpi": ["TLT", "QQQ", "VOO", "SPY", "GLD", "IEF"],
    "ppi": ["TLT", "VOO", "SPY", "IEF"],
    "nonfarm": ["SPY", "QQQ", "VOO", "TLT", "GLD", "DIA"],
    "non-farm": ["SPY", "QQQ", "VOO", "TLT", "GLD", "DIA"],
    "payroll": ["SPY", "QQQ", "VOO", "TLT", "GLD", "DIA"],
    "unemployment": ["SPY", "QQQ", "VOO", "TLT", "DIA"],
    "jobless": ["SPY", "VOO", "DIA"],
    "gdp": ["SPY", "QQQ", "VOO", "DIA", "TLT", "IWM"],
    "pce": ["TLT", "GLD", "QQQ", "VOO", "SPY", "IEF"],
    "ism": ["SPY", "VOO", "DIA", "XLE", "IWM"],
    "retail": ["SPY", "VOO", "DIA", "XLY"],
    "consumer confidence": ["SPY", "VOO", "DIA", "XLY"],
    "michigan": ["SPY", "VOO", "DIA"],
    "adp": ["SPY", "VOO", "DIA", "QQQ"],
    "durable": ["SPY", "DIA", "IWM", "XLI"],
    "housing": ["VNQ", "XHB", "ITB"],
    "home sales": ["VNQ", "XHB"],
    "fomc": ["QQQ", "SPY", "VOO", "TLT", "IEF", "GLD", "DIA", "ARKK"],
    "fed": ["QQQ", "SPY", "VOO", "TLT", "IEF", "GLD"],
    "interest rate": ["QQQ", "SPY", "VOO", "TLT", "IEF", "GLD"],
    "industrial production": ["SPY", "DIA", "XLI"],
    "trade balance": ["SPY", "DIA"],
    "jolts": ["SPY", "VOO", "TLT"],
    "philadelphia": ["SPY", "IWM"],
    "empire state": ["SPY", "IWM"],
    "chicago pmi": ["SPY", "DIA"],
}


def _map_event_to_etfs(event_name: str) -> list[str]:
    """이벤트명에서 영향받는 ETF 티커를 매핑한다.

    Args:
        event_name: 영문 이벤트명.

    Returns:
        영향받는 ETF 티커 리스트.
    """
    name_lower = event_name.lower()
    for keyword, tickers in _EVENT_ETF_MAP.items():
        if keyword in name_lower:
            return tickers
    return ["SPY", "VOO"]  # 기본 fallback


class CalendarService:
    """경제 캘린더 서비스.

    Finnhub API로 실제 이벤트를 가져오고, 실패 시 규칙 기반 fallback.
    """

    def get_events(self, from_date: date, to_date: date) -> list[CalendarEvent]:
        """지정 기간의 경제 이벤트 목록을 반환한다.

        Args:
            from_date: 조회 시작 날짜.
            to_date: 조회 종료 날짜 (포함).

        Returns:
            날짜순 정렬된 CalendarEvent 리스트.
        """
        cache_key = f"calendar:{from_date.isoformat()}:{to_date.isoformat()}"
        cached = get_cached(cache_key)
        if cached is not None:
            logger.debug("캘린더 캐시 히트: %s", cache_key)
            return cached

        logger.info("캘린더 이벤트 조회: %s ~ %s", from_date, to_date)

        # Finnhub API 우선
        events = self._fetch_finnhub(from_date, to_date)

        # Finnhub 실패 시 규칙 기반 fallback
        if not events:
            logger.warning("Finnhub 실패, 규칙 기반 fallback 사용")
            events = self._build_events_fallback(from_date, to_date)

        set_cached(cache_key, events)
        return events

    def _fetch_finnhub(self, from_date: date, to_date: date) -> list[CalendarEvent]:
        """Finnhub API에서 경제 캘린더 이벤트를 가져온다.

        Args:
            from_date: 시작 날짜.
            to_date: 종료 날짜.

        Returns:
            CalendarEvent 리스트. 실패 시 빈 리스트.
        """
        api_key = settings.FINNHUB_API_KEY
        if not api_key:
            logger.warning("FINNHUB_API_KEY 미설정")
            return []

        try:
            resp = httpx.get(
                "https://finnhub.io/api/v1/calendar/economic",
                params={
                    "from": from_date.isoformat(),
                    "to": to_date.isoformat(),
                    "token": api_key,
                },
                timeout=15,
            )
            resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            logger.error("Finnhub API 호출 실패: %s", e)
            return []

        raw_events = data.get("economicCalendar", [])
        if not raw_events:
            logger.info("Finnhub 응답 비어있음 (기간: %s ~ %s)", from_date, to_date)
            return []

        # 미국 이벤트만 필터 + 변환
        events: list[CalendarEvent] = []
        for item in raw_events:
            country = item.get("country", "")
            if country != "US":
                continue

            event_name = item.get("event", "")
            if not event_name:
                continue

            # 날짜 파싱
            time_str = item.get("time", "")
            event_date = from_date  # fallback
            if time_str:
                try:
                    dt = datetime.fromisoformat(time_str.replace("Z", "+00:00"))
                    event_date = dt.date()
                    # KST 변환 (UTC+9)
                    kst_hour = (dt.hour + 9) % 24
                    time_kst = f"{kst_hour:02d}:{dt.minute:02d}"
                except (ValueError, AttributeError):
                    time_kst = ""
            else:
                time_kst = ""

            # 영향도 매핑
            impact_raw = item.get("impact", "").lower()
            if impact_raw == "high":
                impact = ImpactLevel.HIGH
            elif impact_raw == "medium":
                impact = ImpactLevel.MEDIUM
            else:
                impact = ImpactLevel.LOW

            # 이벤트명 → 한국어 번역
            name_ko = _translate_event_name(event_name)

            # 영향 ETF 매핑
            affected = _map_event_to_etfs(event_name)

            events.append(CalendarEvent(
                date=event_date,
                time=time_kst,
                name=event_name,
                name_ko=name_ko,
                impact_level=impact,
                affected_tickers=affected,
                description="",
            ))

        # 날짜순 정렬 + 중복 제거
        events.sort(key=lambda e: (e.date, e.time, e.name))
        seen: set[tuple[date, str]] = set()
        unique: list[CalendarEvent] = []
        for event in events:
            key = (event.date, event.name)
            if key not in seen:
                seen.add(key)
                unique.append(event)

        logger.info("Finnhub 경제 캘린더: US %d건 (원본 %d건)", len(unique), len(raw_events))
        return unique

    def _build_events_fallback(self, from_date: date, to_date: date) -> list[CalendarEvent]:
        """규칙 기반 fallback — Finnhub 실패 시 사용.

        Args:
            from_date: 시작 날짜.
            to_date: 종료 날짜.

        Returns:
            정렬된 CalendarEvent 리스트.
        """
        all_events: list[CalendarEvent] = []

        current = date(from_date.year, from_date.month, 1)
        if to_date.month == 12:
            end_month = date(to_date.year + 1, 1, 1)
        else:
            end_month = date(to_date.year, to_date.month + 1, 1)

        while current < end_month:
            monthly = _generate_monthly_events(current.year, current.month)
            all_events.extend(monthly)
            if current.month == 12:
                current = date(current.year + 1, 1, 1)
            else:
                current = date(current.year, current.month + 1, 1)

        fomc_events = _generate_fomc_events(from_date, to_date)
        all_events.extend(fomc_events)

        filtered = [e for e in all_events if from_date <= e.date <= to_date]
        filtered.sort(key=lambda e: (e.date, e.time, e.name))

        seen: set[tuple[date, str]] = set()
        unique: list[CalendarEvent] = []
        for event in filtered:
            key = (event.date, event.name)
            if key not in seen:
                seen.add(key)
                unique.append(event)

        return unique

    def get_upcoming(self, days: int = 7) -> list[CalendarEvent]:
        """오늘부터 N일 이내의 이벤트를 반환한다.

        Args:
            days: 조회 기간 (일). 기본 7일.

        Returns:
            날짜순 정렬된 CalendarEvent 리스트.
        """
        today = date.today()
        to_date = today + timedelta(days=days)
        return self.get_events(today, to_date)


# 싱글턴 인스턴스
calendar_service = CalendarService()
