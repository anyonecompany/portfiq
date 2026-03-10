import 'event_models.dart';

/// In-memory event queue with batch flush support.
/// Hive persistence can be layered in later.
class EventQueue {
  EventQueue({this.maxBatchSize = 10});

  final int maxBatchSize;
  final List<TrackingEvent> _queue = [];

  /// Number of pending (un-flushed) events.
  int get pendingCount => _queue.length;

  /// Whether the queue has reached the auto-flush threshold.
  bool get shouldFlush => _queue.length >= maxBatchSize;

  /// Add an event to the queue.
  void add(TrackingEvent event) {
    _queue.add(event);
  }

  /// Remove and return up to [maxBatchSize] events for sending.
  List<TrackingEvent> flush() {
    final count = _queue.length < maxBatchSize ? _queue.length : maxBatchSize;
    final batch = _queue.sublist(0, count);
    _queue.removeRange(0, count);
    return batch;
  }

  /// Clear all queued events.
  void clear() {
    _queue.clear();
  }
}
