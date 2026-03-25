import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import '../../shared/widgets/bottom_tab_bar.dart';
import 'feed_screen.dart';
import '../my_etf/my_etf_screen.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';

/// Root scaffold that hosts the bottom tab bar and switches between tabs.
class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  int _currentIndex = 0;

  /// 방문한 탭만 빌드하여 앱 시작 시 4개 API 동시 호출을 방지한다.
  /// 탭 0(홈)은 항상 초기화된 상태로 시작한다.
  final Set<int> _initializedTabs = {0};

  static const _tabNames = ['홈', '내 ETF', '캘린더', '설정'];

  static const _tabScreens = [
    FeedScreen(),
    MyEtfScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    EventTracker.instance.track('tab_switch', properties: {
      'from': _tabNames[_currentIndex],
      'to': _tabNames[index],
    });
    setState(() {
      _currentIndex = index;
      _initializedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(_tabScreens.length, (i) {
          if (!_initializedTabs.contains(i)) {
            return const SizedBox.shrink();
          }
          return _tabScreens[i];
        }),
      ),
      bottomNavigationBar: BottomTabBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
