import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Tracking event data model for analytics pipeline.
class TrackingEvent {
  TrackingEvent({
    required this.name,
    Map<String, dynamic>? properties,
    DateTime? timestamp,
    required this.deviceId,
    String? eventId,
    this.retryCount = 0,
  })  : properties = properties ?? const {},
        timestamp = timestamp ?? DateTime.now(),
        eventId = eventId ?? _uuid.v4();

  final String eventId;
  final String name;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  final String deviceId;
  final int retryCount;

  /// Create a copy with incremented retry count.
  TrackingEvent withRetry() => TrackingEvent(
        name: name,
        properties: properties,
        timestamp: timestamp,
        deviceId: deviceId,
        eventId: eventId,
        retryCount: retryCount + 1,
      );

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'event_name': name,
        'properties': properties,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'device_id': deviceId,
      };

  Map<String, dynamic> toLegacyJson() => {
        'event_id': eventId,
        'name': name,
        'properties': properties,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'device_id': deviceId,
      };

  /// Serialize for Hive persistence.
  Map<String, dynamic> toStorageJson() => {
        'event_id': eventId,
        'name': name,
        'properties': properties,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'device_id': deviceId,
        'retry_count': retryCount,
      };

  /// Deserialize from Hive persistence.
  factory TrackingEvent.fromStorageJson(Map<String, dynamic> json) {
    return TrackingEvent(
      eventId: json['event_id'] as String?,
      name: json['name'] as String,
      properties: Map<String, dynamic>.from(json['properties'] as Map? ?? {}),
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceId: json['device_id'] as String,
      retryCount: (json['retry_count'] as int?) ?? 0,
    );
  }

  @override
  String toString() =>
      'TrackingEvent(id: $eventId, name: $name, properties: $properties)';
}
