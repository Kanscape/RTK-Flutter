import 'dart:convert';

import 'rtk_batch.dart';
import 'rtk_context.dart';
import 'rtk_event.dart';

class RTKQueuedItem {
  RTKQueuedItem({required this.item, this.attemptCount = 0, this.nextRetryAt});

  final RTKBatchItem item;
  int attemptCount;
  DateTime? nextRetryAt;
}

class RTKQueueSelection {
  RTKQueueSelection({required this.items, required this.encodedBytes});

  final List<RTKQueuedItem> items;
  final int encodedBytes;
}

class RTKQueue {
  RTKQueue({required this.maxQueueSize}) {
    if (maxQueueSize <= 0) {
      throw ArgumentError.value(
        maxQueueSize,
        'maxQueueSize',
        'must be positive',
      );
    }
  }

  final int maxQueueSize;
  final List<RTKQueuedItem> _items = [];

  int droppedCount = 0;

  int get length => _items.length;

  List<RTKQueuedItem> get items => List.unmodifiable(_items);

  void enqueue(RTKBatchItem item) {
    _items.add(RTKQueuedItem(item: item));
    while (_items.length > maxQueueSize) {
      _items.removeAt(0);
      droppedCount += 1;
    }
  }

  RTKQueueSelection takeBatch({
    required RTKContext context,
    required int maxItems,
    required int maxBytes,
    String? anonymousId,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now().toUtc();
    final selected = <RTKQueuedItem>[];
    var encodedBytes = _encodedBytes(
      context: context,
      anonymousId: anonymousId,
      items: selected,
    );

    for (final queued in List<RTKQueuedItem>.of(_items)) {
      final nextRetryAt = queued.nextRetryAt;
      if (nextRetryAt != null && nextRetryAt.isAfter(effectiveNow)) {
        continue;
      }
      if (selected.length >= maxItems) {
        break;
      }

      final candidate = [...selected, queued];
      final candidateBytes = _encodedBytes(
        context: context,
        anonymousId: anonymousId,
        items: candidate,
      );

      if (candidateBytes <= maxBytes) {
        selected.add(queued);
        encodedBytes = candidateBytes;
        continue;
      }

      if (selected.isEmpty) {
        _items.remove(queued);
        droppedCount += 1;
        continue;
      }

      break;
    }

    return RTKQueueSelection(items: selected, encodedBytes: encodedBytes);
  }

  void remove(List<RTKQueuedItem> items) {
    final sent = items.toSet();
    _items.removeWhere(sent.contains);
  }

  void removeWhere(bool Function(RTKQueuedItem item) test) {
    _items.removeWhere(test);
  }

  void restore(List<RTKQueuedItem> items) {
    final overflow = items.length - maxQueueSize;
    final start = overflow > 0 ? overflow : 0;
    if (overflow > 0) {
      droppedCount += overflow;
    }
    _items
      ..clear()
      ..addAll(items.skip(start));
  }

  void clear() {
    _items.clear();
  }

  int _encodedBytes({
    required RTKContext context,
    required List<RTKQueuedItem> items,
    String? anonymousId,
  }) {
    final batch = RTKBatch(
      context: context,
      anonymousId: anonymousId,
      items: items.map((item) => item.item).toList(),
    );
    return utf8.encode(jsonEncode(batch.toJson())).length;
  }
}
