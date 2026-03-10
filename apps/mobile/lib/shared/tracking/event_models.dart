/// Tracking event data model for analytics pipeline.
class TrackingEvent {
  TrackingEvent({
    required this.name,
    Map<String, dynamic>? properties,
    DateTime? timestamp,
    required this.deviceId,
  })  : properties = properties ?? const {},
        timestamp = timestamp ?? DateTime.now();

  final String name;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  final String deviceId;

  Map<String, dynamic> toJson() => {
        'name': name,
        'properties': properties,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'device_id': deviceId,
      };

  @override
  String toString() =>
      'TrackingEvent(name: $name, properties: $properties, timestamp: $timestamp)';
}
