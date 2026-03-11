import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/services/api_client.dart';
import 'feed_models.dart';

/// State for the home feed screen.
class FeedState {
  final List<NewsItem> newsItems;
  final BriefingData? briefing;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;

  const FeedState({
    this.newsItems = const [],
    this.briefing,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
  });

  FeedState copyWith({
    List<NewsItem>? newsItems,
    BriefingData? briefing,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
  }) {
    return FeedState(
      newsItems: newsItems ?? this.newsItems,
      briefing: briefing ?? this.briefing,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier that manages feed data — API first, mock fallback.
class FeedNotifier extends StateNotifier<FeedState> {
  FeedNotifier() : super(const FeedState(isLoading: true)) {
    _loadInitialData();
  }

  static const int _pageSize = 20;
  int _currentOffset = 0;

  Future<void> _loadInitialData() async {
    try {
      _currentOffset = 0;
      final result = await _fetchNews(offset: 0, limit: _pageSize);
      final briefing = await _fetchBriefing();
      state = FeedState(
        newsItems: _sortedByImpact(result.items),
        briefing: briefing,
        isLoading: false,
        hasMore: result.hasMore,
      );
      _currentOffset = result.items.length;
    } catch (e) {
      if (kDebugMode) print('[FeedProvider] 초기 로드 실패, mock 사용: $e');
      state = FeedState(
        newsItems: _sortedByImpact(_mockNews),
        briefing: _currentMockBriefing(),
        isLoading: false,
        hasMore: false,
      );
    }
  }

  /// Pull-to-refresh handler.
  Future<void> refreshFeed() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      _currentOffset = 0;
      final result = await _fetchNews(offset: 0, limit: _pageSize);
      final briefing = await _fetchBriefing();
      state = state.copyWith(
        newsItems: _sortedByImpact(result.items),
        briefing: briefing,
        isLoading: false,
        hasMore: result.hasMore,
      );
      _currentOffset = result.items.length;
    } catch (e) {
      if (kDebugMode) print('[FeedProvider] 새로고침 실패: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '새로고침에 실패했습니다',
      );
    }
  }

  /// 다음 페이지 로드 (무한 스크롤).
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _fetchNews(offset: _currentOffset, limit: _pageSize);
      final allItems = [...state.newsItems, ...result.items];
      _currentOffset = allItems.length;
      state = state.copyWith(
        newsItems: allItems,
        isLoadingMore: false,
        hasMore: result.hasMore,
      );
    } catch (e) {
      if (kDebugMode) print('[FeedProvider] 추가 로드 실패: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Fetch news from backend API with pagination.
  Future<_FetchResult> _fetchNews({required int offset, required int limit}) async {
    final response = await ApiClient.instance.get(
      '/api/v1/feed/latest',
      queryParameters: {'offset': offset, 'limit': limit},
    );
    final data = response.data as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>;
    final hasMore = data['has_more'] as bool? ?? false;

    final newsItems = items.map((item) {
      final map = item as Map<String, dynamic>;
      final impacts = (map['impacts'] as List<dynamic>? ?? []).map((imp) {
        final impMap = imp as Map<String, dynamic>;
        return EtfImpact(
          etfTicker: impMap['etf_ticker'] as String? ?? '',
          level: _parseImpactLevel(impMap['level'] as String? ?? 'Low'),
        );
      }).toList();

      return NewsItem(
        id: map['id']?.toString() ?? '',
        headline: map['headline'] as String? ?? '',
        impactReason: map['impact_reason'] as String? ?? '',
        summary3line: map['summary_3line'] as String? ?? '',
        sentiment: _parseSentiment(map['sentiment'] as String? ?? '중립'),
        source: map['source'] as String? ?? '',
        sourceUrl: map['source_url'] as String? ?? '',
        publishedAt: DateTime.tryParse(map['published_at'] ?? '') ?? DateTime.now(),
        impacts: impacts,
      );
    }).toList();

    return _FetchResult(items: newsItems, hasMore: hasMore);
  }

  /// Fetch briefing from backend API.
  Future<BriefingData> _fetchBriefing() async {
    final hour = DateTime.now().hour;
    final type = (hour >= 5 && hour < 17) ? 'morning' : 'night';
    final deviceId = Hive.box('settings').get('device_id', defaultValue: 'unknown');

    final response = await ApiClient.instance.get(
      '/api/v1/briefing/$type',
      queryParameters: {'device_id': deviceId},
    );
    final data = response.data as Map<String, dynamic>;

    final etfChanges = (data['etf_changes'] as List<dynamic>? ?? []).map((c) {
      final cm = c as Map<String, dynamic>;
      return EtfChange(
        ticker: cm['ticker'] as String? ?? '',
        changePercent: (cm['change_pct'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    final checkpoints = (data['checkpoints'] as List<dynamic>? ?? [])
        .map((c) => c.toString())
        .toList();

    return BriefingData(
      type: type == 'morning' ? BriefingType.morning : BriefingType.night,
      title: data['title'] as String? ?? '',
      summary: data['summary'] as String? ?? '',
      etfChanges: etfChanges,
      checkpoints: checkpoints,
    );
  }

  NewsSentiment _parseSentiment(String value) {
    switch (value) {
      case '호재':
        return NewsSentiment.positive;
      case '위험':
        return NewsSentiment.negative;
      default:
        return NewsSentiment.neutral;
    }
  }

  ImpactLevel _parseImpactLevel(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return ImpactLevel.high;
      case 'medium':
        return ImpactLevel.medium;
      default:
        return ImpactLevel.low;
    }
  }

  List<NewsItem> _sortedByImpact(List<NewsItem> items) {
    final sorted = List<NewsItem>.from(items);
    sorted.sort((a, b) {
      const order = {ImpactLevel.high: 0, ImpactLevel.medium: 1, ImpactLevel.low: 2};
      return order[a.highestImpact]!.compareTo(order[b.highestImpact]!);
    });
    return sorted;
  }

  /// Mock briefing based on time of day.
  BriefingData _currentMockBriefing() {
    final hour = DateTime.now().hour;
    return (hour >= 5 && hour < 17) ? _morningBriefing : _nightBriefing;
  }
}

/// Provider for feed state.
final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier();
});

/// Internal result type for paginated news fetch.
class _FetchResult {
  final List<NewsItem> items;
  final bool hasMore;
  const _FetchResult({required this.items, required this.hasMore});
}

// ---------------------------------------------------------------------------
// Mock Data (fallback when API is unreachable)
// ---------------------------------------------------------------------------

final _mockNews = <NewsItem>[
  NewsItem(
    id: '1',
    headline: 'FOMC 의사록 공개: 연준, 금리 인하 시기 신중론 유지',
    impactReason: '연준 위원 다수가 인플레이션 목표 달성 확인까지 금리 인하를 서두르지 않겠다는 입장을 재확인.',
    source: 'Reuters',
    sourceUrl: 'https://reuters.com/fed-minutes',
    publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
    impacts: [
      const EtfImpact(etfTicker: 'QQQ', level: ImpactLevel.high),
      const EtfImpact(etfTicker: 'VOO', level: ImpactLevel.medium),
    ],
  ),
  NewsItem(
    id: '2',
    headline: 'NVIDIA 실적 발표: 데이터센터 매출 전년 대비 409% 증가',
    impactReason: 'AI 인프라 투자 확대로 데이터센터 부문 폭발적 성장.',
    source: 'Bloomberg',
    sourceUrl: 'https://bloomberg.com/nvidia-earnings',
    publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
    impacts: [
      const EtfImpact(etfTicker: 'QQQ', level: ImpactLevel.high),
    ],
  ),
  NewsItem(
    id: '3',
    headline: '미국 소비자물가지수(CPI) 예상치 상회: 전년비 3.1%',
    impactReason: '시장 예상 2.9%를 상회하며 인플레이션 우려 재점화.',
    source: 'CNBC',
    sourceUrl: 'https://cnbc.com/cpi-data',
    publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
    impacts: [
      const EtfImpact(etfTicker: 'VOO', level: ImpactLevel.medium),
      const EtfImpact(etfTicker: 'SCHD', level: ImpactLevel.medium),
    ],
  ),
];

const _morningBriefing = BriefingData(
  type: BriefingType.morning,
  title: '간밤 미장 브리핑',
  summary: 'NVIDIA 실적 호조에 나스닥 +1.2% 마감. FOMC 의사록 매파적 톤에 장 초반 눌림 후 반등.',
  etfChanges: [
    EtfChange(ticker: 'QQQ', changePercent: 1.8),
    EtfChange(ticker: 'VOO', changePercent: 0.6),
    EtfChange(ticker: 'SCHD', changePercent: -0.3),
  ],
  checkpoints: [],
);

const _nightBriefing = BriefingData(
  type: BriefingType.night,
  title: '오늘 밤 체크포인트',
  summary: '',
  etfChanges: [],
  checkpoints: [
    'FOMC 의사록 공개 (한국시간 04:00) — 금리 경로 힌트 주목',
    'NVIDIA 실적 발표 (한국시간 06:20) — AI 투자 모멘텀 확인',
    '미국 주간 신규실업수당 청구건수 — 고용시장 냉각 신호 여부',
  ],
);
