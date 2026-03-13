import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../config/app_config.dart';
import 'event_models.dart';
import 'event_queue.dart';
import 'event_sender.dart';

/// Singleton facade for all analytics tracking.
///
/// Usage:
/// ```dart
/// EventTracker.instance.initialize(Flavor.local, 'device-123');
/// EventTracker.instance.track('etf_registered', properties: {'ticker': 'QQQ'});
/// ```
class EventTracker with WidgetsBindingObserver {
  EventTracker._();

  static final EventTracker instance = EventTracker._();

  late Flavor _flavor;
  late String _deviceId;
  bool _initialized = false;

  final EventQueue _queue = EventQueue();
  final EventSender _sender = EventSender();

  // Session management
  String _sessionId = '';
  DateTime _sessionStartTime = DateTime.now();
  int _screensViewed = 0;
  int _eventsCount = 0;

  /// Initialize the tracker with the current build flavor and device id.
  void initialize(Flavor flavor, String deviceId) {
    _flavor = flavor;
    _deviceId = deviceId;
    _initialized = true;

    // Start observing app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Start first session
    _startNewSession();
  }

  /// Current session ID (included automatically in all events).
  String get sessionId => _sessionId;

  /// Track a named event with optional properties.
  void track(String name, {Map<String, dynamic>? properties}) {
    if (!_initialized) {
      if (kDebugMode) print('[EventTracker] Not initialized — dropping event "$name"');
      return;
    }

    // Inject session_id into all event properties
    final enrichedProperties = <String, dynamic>{
      'session_id': _sessionId,
      ...?properties,
    };

    _eventsCount++;
    if (name == 'screen_viewed' || name == 'screen_view') {
      _screensViewed++;
    }

    final event = TrackingEvent(
      name: name,
      properties: enrichedProperties,
      deviceId: _deviceId,
    );

    if (_flavor == Flavor.local) {
      if (kDebugMode) print('[EventTracker][LOCAL] $event');
      return;
    }

    // qa / production: queue and auto-flush
    _queue.add(event);
    if (_queue.shouldFlush) {
      _flushAsync();
    }
  }

  /// Manually flush the queue (e.g., on app background).
  Future<void> flush() async {
    await _flushAsync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) return;

    if (state == AppLifecycleState.paused) {
      _endSession();
    } else if (state == AppLifecycleState.resumed) {
      _startNewSession();
    }
  }

  void _startNewSession() {
    _sessionId = _generateSessionId();
    _sessionStartTime = DateTime.now();
    _screensViewed = 0;
    _eventsCount = 0;

    track('session_started', properties: {
      'session_id': _sessionId,
    });
  }

  void _endSession() {
    final durationSeconds =
        DateTime.now().difference(_sessionStartTime).inSeconds;

    track('session_ended', properties: {
      'session_id': _sessionId,
      'duration_seconds': durationSeconds,
      'screens_viewed': _screensViewed,
      'events_count': _eventsCount,
    });

    // Flush remaining events before going to background
    flush();
  }

  String _generateSessionId() {
    final now = DateTime.now();
    return 'sess_${now.microsecondsSinceEpoch.toRadixString(36)}';
  }

  Future<void> _flushAsync() async {
    final batch = _queue.flush();
    if (batch.isEmpty) return;

    final success = await _sender.sendBatch(batch);
    if (!success) {
      // Re-queue failed events so they retry next flush
      for (final event in batch) {
        _queue.add(event);
      }
    }
  }

  /// Clean up observer when no longer needed.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
