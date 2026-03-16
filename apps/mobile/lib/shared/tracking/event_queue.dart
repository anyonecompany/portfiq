import 'package:hive_flutter/hive_flutter.dart';

import 'event_models.dart';

/// Hive-backed event queue with batch flush support.
///
/// Events are persisted to Hive so they survive app restarts.
/// Failed events are retried up to [maxRetries] times before being dropped.
class EventQueue {
  EventQueue({this.maxBatchSize = 10, this.maxRetries = 3});

  final int maxBatchSize;
  final int maxRetries;

  static const _boxName = 'event_queue';
  Box? _box;

  // In-memory mirror for fast access (synced with Hive)
  final List<TrackingEvent> _queue = [];

  /// Initialize the queue by opening the Hive box and loading persisted events.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = _box;
    if (box == null) return;

    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw is Map) {
          final event = TrackingEvent.fromStorageJson(
            Map<String, dynamic>.from(raw),
          );
          _queue.add(event);
        }
      } catch (_) {
        // Corrupted entry — remove it
        box.delete(key);
      }
    }
  }

  /// Number of pending (un-flushed) events.
  int get pendingCount => _queue.length;

  /// Whether the queue has reached the auto-flush threshold.
  bool get shouldFlush => _queue.length >= maxBatchSize;

  /// Add an event to the queue (persisted to Hive).
  void add(TrackingEvent event) {
    if (event.retryCount >= maxRetries) {
      // Drop events that exceeded max retries
      return;
    }
    _queue.add(event);
    _box?.put(event.eventId, event.toStorageJson());
  }

  /// Remove and return up to [maxBatchSize] events for sending.
  List<TrackingEvent> flush() {
    final count = _queue.length < maxBatchSize ? _queue.length : maxBatchSize;
    final batch = _queue.sublist(0, count);
    _queue.removeRange(0, count);

    // Remove flushed events from Hive (they'll be re-added on failure)
    for (final event in batch) {
      _box?.delete(event.eventId);
    }

    return batch;
  }

  /// Clear all queued events.
  void clear() {
    _queue.clear();
    _box?.clear();
  }
}
