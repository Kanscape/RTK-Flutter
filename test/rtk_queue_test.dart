import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/rena_rtk.dart';
import 'package:rena_rtk/src/rtk_queue.dart';

void main() {
  RTKEvent event(String name, {Map<String, Object?>? properties}) {
    return RTKEvent(
      name: name,
      timestamp: DateTime.utc(2026, 6, 10, 12),
      properties: properties,
    );
  }

  const context = RTKContext(environment: 'app_store');

  group('RTKQueue', () {
    test('enqueues items in order', () {
      final queue = RTKQueue(maxQueueSize: 10);

      queue.enqueue(event('first'));
      queue.enqueue(event('second'));

      final batch = queue.takeBatch(
        context: context,
        maxItems: 100,
        maxBytes: 256 * 1024,
      );

      expect(batch.items.map((item) => item.item.toJson()['name']), [
        'first',
        'second',
      ]);
    });

    test('drops oldest item when queue exceeds maxQueueSize', () {
      final queue = RTKQueue(maxQueueSize: 2);

      queue.enqueue(event('first'));
      queue.enqueue(event('second'));
      queue.enqueue(event('third'));

      final batch = queue.takeBatch(
        context: context,
        maxItems: 100,
        maxBytes: 256 * 1024,
      );

      expect(batch.items.map((item) => item.item.toJson()['name']), [
        'second',
        'third',
      ]);
      expect(queue.droppedCount, 1);
    });

    test(
      'restore keeps newest items when restored queue exceeds maxQueueSize',
      () {
        final queue = RTKQueue(maxQueueSize: 2);

        queue.restore([
          RTKQueuedItem(item: event('first')),
          RTKQueuedItem(item: event('second')),
          RTKQueuedItem(item: event('third')),
        ]);

        final batch = queue.takeBatch(
          context: context,
          maxItems: 100,
          maxBytes: 256 * 1024,
        );

        expect(batch.items.map((item) => item.item.toJson()['name']), [
          'second',
          'third',
        ]);
        expect(queue.droppedCount, 1);
      },
    );

    test('takes at most maxItems', () {
      final queue = RTKQueue(maxQueueSize: 200);

      for (var index = 0; index < 120; index++) {
        queue.enqueue(event('event_$index'));
      }

      final batch = queue.takeBatch(
        context: context,
        maxItems: 100,
        maxBytes: 256 * 1024,
      );

      expect(batch.items, hasLength(100));
    });

    test('keeps batch under maxBytes and drops oversized single item', () {
      final queue = RTKQueue(maxQueueSize: 10);

      queue.enqueue(event('large', properties: {'note': 'x' * 1024}));
      queue.enqueue(event('small'));

      final batch = queue.takeBatch(
        context: context,
        maxItems: 100,
        maxBytes: 256,
      );

      expect(batch.items, hasLength(1));
      expect(batch.items.single.item.toJson()['name'], 'small');
      expect(batch.encodedBytes, lessThanOrEqualTo(256));
      expect(queue.droppedCount, 1);
    });

    test('removes sent items only', () {
      final queue = RTKQueue(maxQueueSize: 10);

      queue.enqueue(event('first'));
      queue.enqueue(event('second'));

      final batch = queue.takeBatch(
        context: context,
        maxItems: 1,
        maxBytes: 256 * 1024,
      );
      queue.remove(batch.items);

      final remaining = queue.takeBatch(
        context: context,
        maxItems: 100,
        maxBytes: 256 * 1024,
      );

      expect(remaining.items.map((item) => item.item.toJson()['name']), [
        'second',
      ]);
    });

    test('skips items whose nextRetryAt is in the future', () {
      final queue = RTKQueue(maxQueueSize: 10);
      queue.restore([
        RTKQueuedItem(
          item: event('retry_later'),
          nextRetryAt: DateTime.utc(2026, 6, 10, 12, 1),
        ),
        RTKQueuedItem(item: event('send_now')),
      ]);

      final batch = queue.takeBatch(
        context: context,
        maxItems: 100,
        maxBytes: 256 * 1024,
        now: DateTime.utc(2026, 6, 10, 12),
      );

      expect(batch.items.map((item) => item.item.toJson()['name']), [
        'send_now',
      ]);
    });
  });
}
