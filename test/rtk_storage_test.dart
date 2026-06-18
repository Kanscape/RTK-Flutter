import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/rena_rtk.dart';
import 'package:rena_rtk/src/rtk_queue.dart';
import 'package:rena_rtk/src/rtk_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  RTKEvent event(String name) {
    return RTKEvent(name: name, timestamp: DateTime.utc(2026, 6, 10, 12));
  }

  group('RTKStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists anonymous ID across storage instances', () async {
      final firstStorage = await RTKStorage.create();
      final firstId = await firstStorage.anonymousId();

      final secondStorage = await RTKStorage.create();
      final secondId = await secondStorage.anonymousId();

      expect(firstId, startsWith('anon_'));
      expect(secondId, firstId);
    });

    test('persists opt-out state', () async {
      final storage = await RTKStorage.create();

      await storage.setOptOut(true);

      final restored = await RTKStorage.create();
      expect(await restored.isOptedOut(), isTrue);
    });

    test('clears queue when opt-out is enabled', () async {
      final storage = await RTKStorage.create();

      await storage.saveQueue([RTKQueuedItem(item: event('feature_used'))]);
      await storage.setOptOut(true);

      expect(await storage.loadQueue(), isEmpty);
    });

    test('persists queued items with attempts', () async {
      final storage = await RTKStorage.create();
      final queued = RTKQueuedItem(
        item: event('feature_used'),
        attemptCount: 2,
        nextRetryAt: DateTime.utc(2026, 6, 10, 12, 1),
      );

      await storage.saveQueue([queued]);

      final restored = await storage.loadQueue();
      expect(restored, hasLength(1));
      expect(restored.single.item.toJson()['name'], 'feature_used');
      expect(restored.single.attemptCount, 2);
      expect(restored.single.nextRetryAt, DateTime.utc(2026, 6, 10, 12, 1));
    });

    test('persists foreground session checkpoint', () async {
      final storage = await RTKStorage.create();
      final session = RTKForegroundSession(
        startedAt: DateTime.utc(2026, 6, 10, 12),
        lastSeenAt: DateTime.utc(2026, 6, 10, 12, 2),
      );

      await storage.saveForegroundSession(session);

      final restored = await RTKStorage.create();
      expect(await restored.loadForegroundSession(), session);
    });

    test('clears foreground session checkpoint', () async {
      final storage = await RTKStorage.create();
      await storage.saveForegroundSession(
        RTKForegroundSession(
          startedAt: DateTime.utc(2026, 6, 10, 12),
          lastSeenAt: DateTime.utc(2026, 6, 10, 12, 2),
        ),
      );

      await storage.clearForegroundSession();

      final restored = await RTKStorage.create();
      expect(await restored.loadForegroundSession(), isNull);
    });
  });
}
