import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rena_rtk/rena_rtk.dart';
import 'package:rena_rtk/src/rtk_clock.dart';
import 'package:rena_rtk/src/rtk_queue.dart';
import 'package:rena_rtk/src/rtk_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  RTKConfig config({
    bool diagnosticsEnabled = true,
    Duration flushInterval = const Duration(hours: 1),
    int flushAt = 100,
  }) {
    return RTKConfig(
      endpoint: Uri.parse('https://rena.example.com'),
      publicWriteKey: 'public_test',
      debug: false,
      diagnosticsEnabled: diagnosticsEnabled,
      flushAt: flushAt,
      flushInterval: flushInterval,
      trackForegroundDuration: false,
    );
  }

  RTKEvent event(String name) {
    return RTKEvent(name: name, timestamp: DateTime.utc(2026, 6, 10, 12));
  }

  RTKError error(String message) {
    return RTKError(
      errorType: 'StateError',
      message: message,
      timestamp: DateTime.utc(2026, 6, 10, 12),
    );
  }

  List<Map<String, Object?>> sentItems(Map<String, Object?> body) {
    return (body['items']! as List<Object?>)
        .cast<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RenaRTK diagnostics', () {
    test(
      'diagnosticsDisabled startup restores events and drops persisted errors',
      () async {
        final storage = await RTKStorage.create();
        await storage.saveQueue([
          RTKQueuedItem(item: event('feature_used')),
          RTKQueuedItem(item: error('old failure')),
        ]);

        final client = RenaRTK(
          config: config(diagnosticsEnabled: false),
          clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        );
        await client.start();

        final restored = await RTKStorage.create();
        final queued = await restored.loadQueue();
        expect(queued.where((item) => item.item is RTKError), isEmpty);
        expect(
          queued
              .where((item) => item.item is RTKEvent)
              .map((item) => (item.item as RTKEvent).name),
          ['feature_used', 'app_launch'],
        );

        client.dispose();
      },
    );

    test(
      'setDiagnosticsEnabled false removes live and persisted errors only',
      () async {
        final client = RenaRTK(
          config: config(),
          clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        );
        await client.start();

        client.track('feature_used');
        client.addBreadcrumb('before_error');
        client.captureError(StateError('failed'));
        await client.setDiagnosticsEnabled(false);

        final storage = await RTKStorage.create();
        final queued = await storage.loadQueue();
        expect(queued.where((item) => item.item is RTKError), isEmpty);
        expect(
          queued
              .where((item) => item.item is RTKEvent)
              .map((item) => (item.item as RTKEvent).name),
          ['app_launch', 'feature_used'],
        );

        client.dispose();
      },
    );

    test(
      'diagnosticsDisabled blocks errors and breadcrumbs but keeps events',
      () async {
        Map<String, Object?>? body;
        final client = RenaRTK(
          config: config(diagnosticsEnabled: false),
          clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
          httpClient: MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(
              jsonEncode({'accepted': 2, 'rejected': 0, 'rejections': []}),
              200,
            );
          }),
        );
        await client.start();

        client.addBreadcrumb('ignored_breadcrumb');
        client.captureError(StateError('ignored'));
        client.track('feature_used');
        await client.flush();

        final items = sentItems(body!);
        expect(items.map((item) => item['type']), ['event', 'event']);
        expect(items.map((item) => item['name']), [
          'app_launch',
          'feature_used',
        ]);

        client.dispose();
      },
    );

    test('reenabling diagnostics only allows new errors', () async {
      Map<String, Object?>? body;
      final client = RenaRTK(
        config: config(),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({'accepted': 2, 'rejected': 0, 'rejections': []}),
            200,
          );
        }),
      );
      await client.start();

      client.captureError(StateError('old failure'));
      await client.setDiagnosticsEnabled(false);
      await client.setDiagnosticsEnabled(true);
      client.captureError(StateError('new failure'));
      await client.flush();

      final items = sentItems(body!);
      expect(
        items.where((item) => item['type'] == 'error').map(
              (item) => item['message'],
            ),
        ['Bad state: new failure'],
      );

      client.dispose();
    });

    test('flush interval does not send errors after diagnostics close',
        () async {
      final requestStarted = Completer<void>();
      Map<String, Object?>? body;
      final client = RenaRTK(
        config: config(flushInterval: const Duration(milliseconds: 10)),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          if (!requestStarted.isCompleted) {
            requestStarted.complete();
          }
          return http.Response(
            jsonEncode({'accepted': 2, 'rejected': 0, 'rejections': []}),
            200,
          );
        }),
      );
      await client.start();

      client.captureError(StateError('closed'));
      client.track('feature_used');
      await client.setDiagnosticsEnabled(false);

      await requestStarted.future;
      final items = sentItems(body!);
      expect(items.map((item) => item['type']), ['event', 'event']);
      expect(items.map((item) => item['name']), [
        'app_launch',
        'feature_used',
      ]);

      client.dispose();
    });
  });
}
