import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import '../../shared/widgets/glass_card.dart';
import 'calendar_provider.dart';

/// Economic event on the calendar.
class CalendarEvent {
  final DateTime date;
  final String time;
  final String name;
  final List<String> impactEtfs;

  const CalendarEvent({
    required this.date,
    required this.time,
    required this.name,
    required this.impactEtfs,
  });
}

/// Economic calendar tab screen.
///
/// Fetches events from the backend API via [calendarProvider].
/// Shows a monthly calendar grid with event dots, and a list of
/// events for the selected date.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  static const List<String> _weekDays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    EventTracker.instance.track('screen_viewed', properties: {
      'screen_name': 'calendar',
    });
  }

  /// Get events for a specific date from provider state.
  List<CalendarEvent> _eventsForDate(DateTime date, List<CalendarEvent> events) {
    return events
        .where((e) =>
            e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day)
        .toList();
  }

  /// Check if a date has events.
  bool _hasEvents(DateTime date, List<CalendarEvent> events) {
    return events.any((e) =>
        e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day);
  }

  /// Check if two dates are the same day.
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Navigate to previous month.
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    ref.read(calendarProvider.notifier).loadMonth(_currentMonth);
  }

  /// Navigate to next month.
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    ref.read(calendarProvider.notifier).loadMonth(_currentMonth);
  }

  /// Select a date.
  void _selectDate(DateTime date, List<CalendarEvent> events) {
    setState(() {
      _selectedDate = date;
    });
    EventTracker.instance.track('date_select', properties: {
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'has_events': _hasEvents(date, events),
    });
  }

  /// Get all days to display in the calendar grid for the current month.
  List<DateTime?> _calendarDays() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstWeekday = firstDay.weekday % 7; // Sunday = 0

    final days = <DateTime?>[];

    // Leading empty cells
    for (int i = 0; i < firstWeekday; i++) {
      days.add(null);
    }

    // Days of the month
    for (int d = 1; d <= lastDay.day; d++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, d));
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(calendarProvider);
    final events = calendarState.events;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedEvents = _eventsForDate(_selectedDate, events);

    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      appBar: AppBar(
        title: const Text('경제 캘린더'),
      ),
      body: Column(
        children: [
          // Month navigator
          _buildMonthNavigator(),
          const SizedBox(height: 8),
          // Calendar grid
          _buildCalendarGrid(todayDate, events),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Selected date label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_selectedDate.month}월 ${_selectedDate.day}일 일정',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PortfiqTheme.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Events list — loading, error, empty, or data
          Expanded(
            child: _buildEventsList(calendarState, selectedEvents, events),
          ),
        ],
      ),
    );
  }

  /// 이벤트 목록 영역: 로딩/에러/빈 상태/데이터 분기.
  Widget _buildEventsList(
    CalendarState calendarState,
    List<CalendarEvent> selectedEvents,
    List<CalendarEvent> allEvents,
  ) {
    // 로딩 shimmer
    if (calendarState.isLoading) {
      return _buildLoadingShimmer();
    }

    // 에러 상태
    if (calendarState.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: PortfiqTheme.textSecondary.withAlpha(100),
            ),
            const SizedBox(height: 12),
            Text(
              calendarState.errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: PortfiqTheme.textSecondary.withAlpha(180),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                ref.read(calendarProvider.notifier).refresh();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    // 이벤트 없음
    if (selectedEvents.isEmpty) {
      return Center(
        child: Text(
          '이벤트 없음',
          style: TextStyle(
            fontSize: 14,
            color: PortfiqTheme.textSecondary.withAlpha(128),
          ),
        ),
      );
    }

    // 이벤트 목록
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: selectedEvents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildEventCard(selectedEvents[index]);
      },
    );
  }

  /// 로딩 shimmer 효과.
  Widget _buildLoadingShimmer() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return GlassCard(
          padding: const EdgeInsets.all(PortfiqSpacing.space16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time placeholder
              Container(
                width: 48,
                height: 16,
                decoration: BoxDecoration(
                  color: PortfiqTheme.textSecondary.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name placeholder
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: PortfiqTheme.textSecondary.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ETF badges placeholder
                    Row(
                      children: List.generate(
                        3,
                        (_) => Container(
                          width: 40,
                          height: 20,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: PortfiqTheme.textSecondary.withAlpha(20),
                            borderRadius: BorderRadius.circular(PortfiqTheme.radiusChip),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthNavigator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(
              Icons.chevron_left,
              color: PortfiqTheme.textPrimary,
            ),
          ),
          Text(
            '${_currentMonth.year}년 ${_currentMonth.month}월',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PortfiqTheme.textPrimary,
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(
              Icons.chevron_right,
              color: PortfiqTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime todayDate, List<CalendarEvent> events) {
    final days = _calendarDays();
    final rowCount = (days.length / 7).ceil();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          // Weekday header row
          Row(
            children: _weekDays.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PortfiqTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          // Day cells
          ...List.generate(rowCount, (row) {
            return Row(
              children: List.generate(7, (col) {
                final index = row * 7 + col;
                final date = index < days.length ? days[index] : null;
                return Expanded(child: _buildDayCell(date, todayDate, events));
              }),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDayCell(DateTime? date, DateTime todayDate, List<CalendarEvent> events) {
    if (date == null) {
      return const SizedBox(height: 44);
    }

    final isSelected = _isSameDay(date, _selectedDate);
    final isToday = _isSameDay(date, todayDate);
    final hasEvents = _hasEvents(date, events);

    return GestureDetector(
      onTap: () => _selectDate(date, events),
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? PortfiqTheme.accent : Colors.transparent,
                border: isToday && !isSelected
                    ? Border.all(color: PortfiqTheme.accent, width: 1.5)
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isSelected
                      ? PortfiqTheme.textPrimary
                      : isToday
                          ? PortfiqTheme.accent
                          : PortfiqTheme.textPrimary,
                ),
              ),
            ),
            if (hasEvents)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: PortfiqTheme.accent,
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    return GestureDetector(
      onTap: () {
        EventTracker.instance.track('event_tap', properties: {
          'event_name': event.name,
          'event_time': event.time,
        });
      },
      child: GlassCard(
        padding: const EdgeInsets.all(PortfiqSpacing.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time
            SizedBox(
              width: 48,
              child: Text(
                event.time,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PortfiqTheme.accent,
                  fontFamily: 'Pretendard',
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + ETF badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PortfiqTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: event.impactEtfs.map((etf) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: PortfiqTheme.accent.withAlpha(26),
                          borderRadius:
                              BorderRadius.circular(PortfiqTheme.radiusChip),
                        ),
                        child: Text(
                          etf,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: PortfiqTheme.accentLight,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
