import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/services/api_client.dart';

/// Notification preference state.
class NotificationPrefs {
  final bool morningBriefing;
  final bool nightCheckpoint;
  final bool urgentNews;

  const NotificationPrefs({
    this.morningBriefing = true,
    this.nightCheckpoint = true,
    this.urgentNews = false,
  });

  NotificationPrefs copyWith({
    bool? morningBriefing,
    bool? nightCheckpoint,
    bool? urgentNews,
  }) {
    return NotificationPrefs(
      morningBriefing: morningBriefing ?? this.morningBriefing,
      nightCheckpoint: nightCheckpoint ?? this.nightCheckpoint,
      urgentNews: urgentNews ?? this.urgentNews,
    );
  }

  Map<String, dynamic> toJson() => {
        'morning_briefing': morningBriefing,
        'night_checkpoint': nightCheckpoint,
        'urgent_news': urgentNews,
      };

  factory NotificationPrefs.fromJson(Map<dynamic, dynamic> json) {
    return NotificationPrefs(
      morningBriefing: json['morning_briefing'] as bool? ?? true,
      nightCheckpoint: json['night_checkpoint'] as bool? ?? true,
      urgentNews: json['urgent_news'] as bool? ?? false,
    );
  }
}

/// Manages notification preferences with Hive persistence + backend sync.
class SettingsNotifier extends StateNotifier<NotificationPrefs> {
  SettingsNotifier() : super(const NotificationPrefs()) {
    _loadFromHive();
  }

  static const String _hiveKey = 'notification_prefs';

  String get _deviceId =>
      Hive.box('settings').get('device_id', defaultValue: 'unknown') as String;

  /// Load saved preferences from Hive on init.
  void _loadFromHive() {
    try {
      final box = Hive.box('settings');
      final raw = box.get(_hiveKey);
      if (raw != null && raw is Map) {
        state = NotificationPrefs.fromJson(raw);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[SettingsProvider] Hive 로드 실패: $e');
      }
    }
  }

  /// Toggle morning briefing.
  void setMorningBriefing(bool value) {
    state = state.copyWith(morningBriefing: value);
    _persist();
  }

  /// Toggle night checkpoint.
  void setNightCheckpoint(bool value) {
    state = state.copyWith(nightCheckpoint: value);
    _persist();
  }

  /// Toggle urgent news.
  void setUrgentNews(bool value) {
    state = state.copyWith(urgentNews: value);
    _persist();
  }

  /// Save to Hive and sync to backend (fire-and-forget).
  void _persist() {
    _saveToHive();
    _syncToBackend();
  }

  void _saveToHive() {
    try {
      final box = Hive.box('settings');
      box.put(_hiveKey, state.toJson());
    } catch (e) {
      if (kDebugMode) {
        print('[SettingsProvider] Hive 저장 실패: $e');
      }
    }
  }

  /// Fire-and-forget PUT to backend.
  void _syncToBackend() {
    final deviceId = _deviceId;
    final body = state.toJson();

    ApiClient.instance.dio
        .put('/api/v1/devices/$deviceId/preferences', data: body)
        .then((_) {
      if (kDebugMode) {
        print('[SettingsProvider] 백엔드 동기화 완료');
      }
    }).catchError((e) {
      if (kDebugMode) {
        print('[SettingsProvider] 백엔드 동기화 실패 (무시): $e');
      }
    });
  }
}

/// Provider for notification preferences.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, NotificationPrefs>((ref) {
  return SettingsNotifier();
});
