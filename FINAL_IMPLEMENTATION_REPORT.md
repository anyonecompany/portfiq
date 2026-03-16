# Portfiq 최종 구현 리포트

> 일시: 2026-03-16
> 작업자: AI Senior Fullstack Architect (Claude Opus 4.6)

---

## PHASE 1: 프로젝트 현황 분석

### 이미 구현된 것 (변경 불필요)
| 항목 | 상태 | 비고 |
|------|------|------|
| 브리핑 ETF 그룹 캐싱 | ✅ 구현됨 | `_briefing_signature()` + `_daily_cache_key()` |
| 뉴스 배치 번역 | ✅ 구현됨 | `_BATCH_SIZE=10`, 배치 프롬프트 |
| 인메모리 캐시 | ✅ 구현됨 | `cachetools.TTLCache` (15분, 100 entries) |
| 가격 캐시 + stale fallback | ✅ 구현됨 | 인메모리 TTL + stale_cache |
| ETF 시드 데이터 | ✅ 구현됨 | 143개 ETF (etf_master.json) |
| 분석 서비스 | ✅ 구현됨 | 섹터, 매크로, 비교, 변동 |
| 스케줄러 | ✅ 구현됨 | 뉴스 10분, 브리핑 아침/밤, 주말, 집계 |

### Gemini 호출 위치 (2개 서비스)
- `services/news_service.py` — 뉴스 번역/요약 (배치 처리)
- `services/briefing_service.py` — 브리핑 생성 (그룹 캐시)

### 비용 최적화 사전 진단
- 브리핑: ✅ ETF 조합 기반 그룹 캐시 이미 적용 (유저별 생성 아님)
- 뉴스: ✅ 배치 번역 이미 적용 (10건/1회 Gemini)
- 피드 API: ✅ Gemini 미호출 (DB 데이터만 반환)
- 가격: ⚠️ 고정 TTL 5분 → 적응형 TTL로 개선 필요
- DB 2계층 캐시: ❌ 미구현

---

## API 비용 최적화 적용 내역

| 영역 | 이전 | 이후 | 예상 절감 |
|------|------|------|----------|
| 가격 데이터 TTL | 고정 5분 | 장중 15분 / 장외 6시간 | ~70% (주말/장외) |
| 브리핑 생성 | ETF 그룹 캐시 (이미 최적) | 변경 없음 | - |
| 뉴스 번역 | 배치 10건 (이미 최적) | 변경 없음 | - |
| DB 캐시 테이블 | 미구현 | api_cache 테이블 + 마이그레이션 | 신규 인프라 |
| ETF 유니버스 | 143개 하드코딩 | etf_universe 테이블 (동적 확장 준비) | 확장성 |

---

## P2 이슈 해결

### [P2-1] 이벤트 큐 Hive 영속화 ✅
| 항목 | 상태 |
|------|------|
| EventQueue Hive box 영속화 | ✅ `event_queue` box |
| 앱 시작 시 미전송 이벤트 복구 | ✅ `_loadFromHive()` |
| 전송 성공 시 Hive 삭제 | ✅ `flush()` 내 delete |
| retryCount 필드 추가 | ✅ `TrackingEvent.retryCount` |
| 최대 3회 재시도 후 드랍 | ✅ `maxRetries = 3` |

### [P2-2] 30초 타이머 전송 ✅
| 항목 | 상태 |
|------|------|
| Timer.periodic(30초) | ✅ `_startFlushTimer()` |
| 포그라운드에서만 동작 | ✅ paused → cancel, resumed → restart |
| 10개 누적 즉시 전송 병행 | ✅ `shouldFlush` 유지 |

### [P2-3] event_id UUID ✅
| 항목 | 상태 |
|------|------|
| uuid 패키지 추가 | ✅ `uuid: ^4.3.3` |
| TrackingEvent.eventId (UUID v4) | ✅ 자동 생성 |
| toJson()에 event_id 포함 | ✅ |
| 백엔드 event_id UNIQUE INDEX | ✅ 마이그레이션 006 |
| Hive 직렬화/역직렬화 | ✅ `toStorageJson()` / `fromStorageJson()` |

---

## 추가 구현

### 적응형 가격 캐시 TTL ✅
| 파일 | 내용 |
|------|------|
| `backend/services/cache_ttl.py` | CacheTTL 상수 + `get_market_aware_price_ttl()` |
| `backend/services/price_service.py` | 고정 5분 → 적응형 TTL (장중 15분, 장외 6시간) |

### DB 스키마 확장 ✅
| 파일 | 내용 |
|------|------|
| `backend/migrations/006_event_id_unique_and_api_cache.sql` | events.event_id UNIQUE, api_cache 테이블, etf_universe 테이블 |

### event_schema.md v2.1.0 ✅
- 21개 미등록 이벤트 추가 (app_opened, aha_moment_feed_viewed, etf_report_*, share_*, push_*, calendar_* 등)

---

## 수정/생성한 파일 전체 목록

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `apps/mobile/pubspec.yaml` | 수정 | uuid: ^4.3.3 추가 |
| `apps/mobile/lib/shared/tracking/event_models.dart` | 재작성 | eventId UUID v4, retryCount, Hive 직렬화 |
| `apps/mobile/lib/shared/tracking/event_queue.dart` | 재작성 | Hive 영속화, maxRetries |
| `apps/mobile/lib/shared/tracking/event_tracker.dart` | 재작성 | 30초 Timer, async initialize, Hive 복구 |
| `apps/mobile/lib/main.dart` | 수정 | await EventTracker.instance.initialize() |
| `apps/mobile/lib/main_local.dart` | 수정 | await EventTracker.instance.initialize() |
| `apps/mobile/lib/main_qa.dart` | 수정 | await EventTracker.instance.initialize() |
| `apps/mobile/lib/main_production.dart` | 수정 | await EventTracker.instance.initialize() |
| `backend/services/cache_ttl.py` | 신규 | CacheTTL 상수 + 적응형 가격 TTL |
| `backend/services/price_service.py` | 수정 | 고정 TTL → 적응형 TTL 적용 |
| `backend/migrations/006_event_id_unique_and_api_cache.sql` | 신규 | event_id UNIQUE, api_cache, etf_universe |
| `docs/event_schema.md` | 수정 | v2.0.0 → v2.1.0, 21개 이벤트 추가 |

---

## 리그레션 결과

| 항목 | 결과 |
|------|------|
| flutter analyze | **0 error, 0 warning** ✅ |
| pytest | **13 passed, 0 failed** ✅ |
| 기존 ETF 호환 | ✅ 기존 143개 시드 변경 없음 |
| 기존 API 경로 | ✅ 변경 없음 |

---

## 추가 필요 작업 (운영자 액션)

1. **Supabase에 마이그레이션 006 실행**: `backend/migrations/006_event_id_unique_and_api_cache.sql`
2. **api_cache 만료 정리 배치**: Supabase에서 daily cron 설정 (`DELETE FROM api_cache WHERE expired_at < now()`)
3. **etf_universe 시드 로딩**: 초기 200개 ETF를 etf_universe 테이블에 INSERT (선택)
