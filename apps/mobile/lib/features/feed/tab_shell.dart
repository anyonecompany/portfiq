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

  static const _tabNames = ['홈', '내 ETF', '캘린더', '설정'];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    EventTracker.instance.track('tab_switch', properties: {
      'from': _tabNames[_currentIndex],
      'to': _tabNames[index],
    });
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          FeedScreen(),
          MyEtfScreen(),
          CalendarScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomTabBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
