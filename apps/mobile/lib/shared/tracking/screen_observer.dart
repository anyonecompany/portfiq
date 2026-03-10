import 'package:flutter/material.dart';

import 'event_tracker.dart';

/// A [NavigatorObserver] that automatically tracks `screen_viewed` events
/// whenever a route is pushed, popped, or replaced.
class ScreenObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreen(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackScreen(newRoute, oldRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackScreen(previousRoute, route);
    }
  }

  void _trackScreen(Route<dynamic> route, Route<dynamic>? fromRoute) {
    final screenName = route.settings.name;
    if (screenName != null && screenName.isNotEmpty) {
      final properties = <String, dynamic>{
        'screen_name': screenName,
      };

      // Include previous screen for navigation flow analysis
      final previousName = fromRoute?.settings.name;
      if (previousName != null && previousName.isNotEmpty) {
        properties['previous_screen'] = previousName;
      }

      // Extract route parameters if available
      final arguments = route.settings.arguments;
      if (arguments is Map<String, dynamic>) {
        for (final entry in arguments.entries) {
          if (entry.value is String ||
              entry.value is int ||
              entry.value is double ||
              entry.value is bool) {
            properties['param_${entry.key}'] = entry.value;
          }
        }
      }

      EventTracker.instance.track(
        'screen_viewed',
        properties: properties,
      );
    }
  }
}
