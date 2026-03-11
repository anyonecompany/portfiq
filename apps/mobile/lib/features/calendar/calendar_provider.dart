import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/api_client.dart';
import 'calendar_screen.dart';

/// 캘린더 탭 상태.
class CalendarState {
  final List<CalendarEvent> events;
  final bool isLoading;
  final String? errorMessage;

  /// 현재 캐시된 월 (중복 fetch 방지).
  final DateTime? cachedMonth;

  const CalendarState({
    this.events = const [],
    this.isLoading = false,
    this.errorMessage,
    this.cachedMonth,
  });

  CalendarState copyWith({
    List<CalendarEvent>? events,
    bool? isLoading,
    String? errorMessage,
    DateTime? cachedMonth,
  }) {
    return CalendarState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      cachedMonth: cachedMonth ?? this.cachedMonth,
    );
  }
}

/// 경제 캘린더 상태 관리 노티파이어 — API first, 빈 리스트 fallback.
class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier() : super(const CalendarState(isLoading: true)) {
    final now = DateTime.now();
    loadMonth(DateTime(now.year, now.month));
  }

  /// 특정 월의 이벤트를 로드한다.
  ///
  /// 이미 캐시된 월이면 재요청하지 않는다.
  /// [force]를 true로 주면 캐시를 무시하고 다시 요청한다.
  Future<void> loadMonth(DateTime month, {bool force = false}) async {
    final target = DateTime(month.year, month.month);

    // 이미 같은 월이 캐시돼 있고, 강제가 아니면 스킵
    if (!force &&
        state.cachedMonth != null &&
        state.cachedMonth!.year == target.year &&
        state.cachedMonth!.month == target.month &&
        state.events.isNotEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final events = await _fetchEvents(target);
      state = CalendarState(
        events: events,
        isLoading: false,
        cachedMonth: target,
      );
    } catch (e) {
      if (kDebugMode) print('[CalendarProvider] 이벤트 로드 실패: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: '경제 캘린더를 불러올 수 없습니다',
        events: [],
        cachedMonth: target,
      );
    }
  }

  /// 현재 캐시된 월을 새로고침한다.
  Future<void> refresh() async {
    final month = state.cachedMonth ?? DateTime(DateTime.now().year, DateTime.now().month);
    await loadMonth(month, force: true);
  }

  /// 백엔드 API에서 해당 월의 이벤트를 가져온다.
  Future<List<CalendarEvent>> _fetchEvents(DateTime month) async {
    // from: 해당 월 1일, to: 다음 달 1일 - 1일
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0); // 해당 월 마지막 날

    final fromStr =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final toStr =
        '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';

    final response = await ApiClient.instance.get(
      '/api/v1/calendar/events',
      queryParameters: {'from': fromStr, 'to': toStr},
    );

    final data = response.data as Map<String, dynamic>;
    final items = data['events'] as List<dynamic>;

    return items.map((item) {
      final map = item as Map<String, dynamic>;
      final dateStr = map['date'] as String? ?? '';
      final parts = dateStr.split('-');
      final eventDate = parts.length == 3
          ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
          : DateTime.now();

      final tickers = (map['affected_tickers'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [];

      return CalendarEvent(
        date: eventDate,
        time: map['time'] as String? ?? '',
        name: map['name_ko'] as String? ?? map['name'] as String? ?? '',
        impactEtfs: tickers,
      );
    }).toList();
  }
}

/// Provider.
final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier();
});
