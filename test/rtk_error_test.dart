import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/rena_rtk.dart';
import 'package:rena_rtk/src/rtk_clock.dart';
import 'package:rena_rtk/src/rtk_queue.dart';

void main() {
  RTKConfig config({int maxBreadcrumbs = 50}) => RTKConfig(
        endpoint: Uri.parse('https://rena.example.com'),
        publicWriteKey: 'public_test',
        maxBreadcrumbs: maxBreadcrumbs,
        debug: false,
      );

  group('RenaRTK telemetry capture', () {
    test('beforeSend can drop telemetry', () {
      final queue = RTKQueue(maxQueueSize: 10);
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          debug: false,
          beforeSend: (item) => null,
        ),
        queue: queue,
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
      );

      client.track('feature_used');
      client.captureError(StateError('failed'));

      expect(queue.length, 0);
    });

    test('beforeSend can replace telemetry', () {
      final queue = RTKQueue(maxQueueSize: 10);
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          debug: false,
          beforeSend: (item) => RTKEvent(
            name: 'replacement',
            timestamp: DateTime.utc(2026, 6, 10, 12),
          ),
        ),
        queue: queue,
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
      );

      client.track('feature_used');

      final batch = queue.takeBatch(
        context: const RTKContext(),
        maxItems: 100,
        maxBytes: 256 * 1024,
      );

      expect(batch.items.single.item.toJson()['name'], 'replacement');
    });

    test('track enqueues event with super properties', () {
      final queue = RTKQueue(maxQueueSize: 10);
      final client = RenaRTK(
        config: config(),
        queue: queue,
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
      );

      client.setSuperProperties({'source': 'toolbar'});
      client.track('feature_used', properties: {'feature': 'search'});

      final batch = queue.takeBatch(
        context: const RTKContext(),
        maxItems: 100,
        maxBytes: 256 * 1024,
      );

      expect(batch.items.single.item.toJson(), {
        'type': 'event',
        'name': 'feature_used',
        'timestamp': '2026-06-10T12:00:00Z',
        'properties': {'source': 'toolbar', 'feature': 'search'},
      });
    });

    test('captureError enqueues error with current breadcrumbs', () {
      final queue = RTKQueue(maxQueueSize: 10);
      final clock = FakeRTKClock(DateTime.utc(2026, 6, 10, 12));
      final client = RenaRTK(config: config(), queue: queue, clock: clock);

      client.addBreadcrumb('sync_started', properties: {'source': 'manual'});
      clock.nowValue = DateTime.utc(2026, 6, 10, 12, 0, 3);
      client.captureError(
        StateError('Request timeout'),
        stackTrace: StackTrace.fromString('NetworkClient.send'),
        properties: {'module': 'sync'},
      );

      final batch = queue.takeBatch(
        context: const RTKContext(),
        maxItems: 100,
        maxBytes: 256 * 1024,
      );
      final json = batch.items.single.item.toJson();

      expect(json['type'], 'error');
      expect(json['error_type'], 'StateError');
      expect(json['message'], contains('Request timeout'));
      expect(json['stack'], 'NetworkClient.send');
      expect(json['timestamp'], '2026-06-10T12:00:03Z');
      expect(json['properties'], {'module': 'sync'});
      expect(json['breadcrumbs'], [
        {
          'name': 'sync_started',
          'timestamp': '2026-06-10T12:00:00Z',
          'properties': {'source': 'manual'},
        },
      ]);
    });

    test('keeps only maxBreadcrumbs recent breadcrumbs', () {
      final queue = RTKQueue(maxQueueSize: 10);
      final client = RenaRTK(
        config: config(maxBreadcrumbs: 2),
        queue: queue,
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
      );

      client.addBreadcrumb('first');
      client.addBreadcrumb('second');
      client.addBreadcrumb('third');
      client.captureError(StateError('failed'));

      final batch = queue.takeBatch(
        context: const RTKContext(),
        maxItems: 100,
        maxBytes: 256 * 1024,
      );
      final json = batch.items.single.item.toJson();
      final breadcrumbs = json['breadcrumbs']! as List<Object?>;

      expect(breadcrumbs.map((breadcrumb) => (breadcrumb! as Map)['name']), [
        'second',
        'third',
      ]);
    });
  });
}
