import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/services/api_client.dart';

/// Notification preference state.
class NotificationPrefs {
  final bool morningBriefing;
  final bool nightCheckpoint;
  final bool urgentNews;
  final int morningHour;
  final int morningMinute;
  final int nightHour;
  final int nightMinute;

  const NotificationPrefs({
    this.morningBriefing = true,
    this.nightCheckpoint = true,
    this.urgentNews = false,
    this.morningHour = 8,
    this.morningMinute = 35,
    this.nightHour = 22,
    this.nightMinute = 0,
  });

  NotificationPrefs copyWith({
    bool? morningBriefing,
    bool? nightCheckpoint,
    bool? urgentNews,
    int? morningHour,
    int? morningMinute,
    int? nightHour,
    int? nightMinute,
  }) {
    return NotificationPrefs(
      morningBriefing: morningBriefing ?? this.morningBriefing,
      nightCheckpoint: nightCheckpoint ?? this.nightCheckpoint,
      urgentNews: urgentNews ?? this.urgentNews,
      morningHour: morningHour ?? this.morningHour,
      morningMinute: morningMinute ?? this.morningMinute,
      nightHour: nightHour ?? this.nightHour,
      nightMinute: nightMinute ?? this.nightMinute,
    );
  }

  /// Format time as HH:MM string.
  String get morningTimeStr =>
      '${morningHour.toString().padLeft(2, '0')}:${morningMinute.toString().padLeft(2, '0')}';

  String get nightTimeStr =>
      '${nightHour.toString().padLeft(2, '0')}:${nightMinute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'morning_briefing': morningBriefing,
        'night_checkpoint': nightCheckpoint,
        'urgent_news': urgentNews,
        'morning_hour': morningHour,
        'morning_minute': morningMinute,
        'night_hour': nightHour,
        'night_minute': nightMinute,
      };

  factory NotificationPrefs.fromJson(Map<dynamic, dynamic> json) {
    return NotificationPrefs(
      morningBriefing: json['morning_briefing'] as bool? ?? true,
      nightCheckpoint: json['night_checkpoint'] as bool? ?? true,
      urgentNews: json['urgent_news'] as bool? ?? false,
      morningHour: json['morning_hour'] as int? ?? 8,
      morningMinute: json['morning_minute'] as int? ?? 35,
      nightHour: json['night_hour'] as int? ?? 22,
      nightMinute: json['night_minute'] as int? ?? 0,
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

  /// Set morning briefing time.
  void setMorningTime(int hour, int minute) {
    state = state.copyWith(morningHour: hour, morningMinute: minute);
    _persist();
  }

  /// Set night checkpoint time.
  void setNightTime(int hour, int minute) {
    state = state.copyWith(nightHour: hour, nightMinute: minute);
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
