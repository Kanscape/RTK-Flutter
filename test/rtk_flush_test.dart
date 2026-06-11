import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rena_rtk/rena_rtk.dart';
import 'package:rena_rtk/src/rtk_clock.dart';
import 'package:rena_rtk/src/rtk_ids.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  RTKConfig config() => RTKConfig(
        endpoint: Uri.parse('https://rena.example.com'),
        publicWriteKey: 'public_test',
        environment: 'production',
        appVersion: '1.0.0',
        buildNumber: '100',
        platform: 'ios',
        debug: false,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RenaRTK flush', () {
    test(
      'sends queued items with context and clears successful batch',
      () async {
        Map<String, Object?>? body;
        final client = RenaRTK(
          config: config(),
          clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
          idGenerator: RTKIdGenerator(seed: 1),
          httpClient: MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(
              jsonEncode({'accepted': 1, 'rejected': 0, 'rejections': []}),
              200,
            );
          }),
        );
        await client.start();

        client.track('feature_used');
        await client.flush();

        expect(client.pendingCount, 0);
        expect(body?['context'], {
          'platform': 'ios',
          'environment': 'production',
          'app_version': '1.0.0',
          'build_number': '100',
          'locale':
              WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
        });
        expect(body?['anonymous_id'], startsWith('anon_'));
        expect(body?['session_id'], startsWith('sess_'));
        expect(body?['items'], hasLength(1));
        expect((body?['items']! as List).single['name'], 'feature_used');
        expect(body?.containsKey('project_id'), isFalse);
      },
    );

    test('fills platform and locale context when config omits them', () async {
      Map<String, Object?>? body;
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          environment: 'production',
          debug: false,
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({'accepted': 1, 'rejected': 0, 'rejections': []}),
            200,
          );
        }),
      );
      await client.start();

      client.track('feature_used');
      await client.flush();

      final context = body!['context']! as Map<String, Object?>;
      expect(context['platform'], defaultTargetPlatform.name);
      expect(
        context['locale'],
        WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
      );

      client.dispose();
    });

    test('debug logging reports unsupported property drops', () async {
      final originalDebugPrint = debugPrint;
      final messages = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        messages.add(message ?? '');
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      Map<String, Object?>? body;
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_secret_1234567890',
          environment: 'production',
          debug: true,
          flushInterval: const Duration(hours: 1),
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({'accepted': 1, 'rejected': 0, 'rejections': []}),
            200,
          );
        }),
      );
      await client.start();

      client.track(
        'feature_used',
        properties: {'kept': 'yes', 'dropped': Object()},
      );
      await client.flush();

      final output = messages.join('\n');
      expect(
        output,
        contains('dropped_property path=dropped reason=unsupported_value'),
      );
      expect(output, isNot(contains('public_secret_1234567890')));
      final item = (body!['items']! as List<Object?>).single! as Map;
      expect(item['properties'], {'kept': 'yes'});

      client.dispose();
    });

    test('preserves events tracked before start', () async {
      Map<String, Object?>? body;
      final client = RenaRTK(
        config: config(),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({'accepted': 1, 'rejected': 0, 'rejections': []}),
            200,
          );
        }),
      );

      client.track('feature_used');
      await client.flush();

      expect(client.pendingCount, 0);
      expect((body?['items']! as List).single['name'], 'feature_used');
    });

    test('persists queued telemetry before any flush', () async {
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          environment: 'production',
          debug: false,
          flushAt: 100,
          flushInterval: const Duration(hours: 1),
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
      );
      await client.start();

      client.track('feature_used');
      await Future<void>.delayed(Duration.zero);

      final restored = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          environment: 'production',
          debug: false,
          flushAt: 100,
          flushInterval: const Duration(hours: 1),
        ),
      );
      await restored.start();

      expect(restored.pendingCount, 1);

      client.dispose();
      restored.dispose();
    });

    test('flushAt triggers asynchronous flush', () async {
      final requestStarted = Completer<void>();
      final responseGate = Completer<void>();
      var requestCount = 0;
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          environment: 'production',
          debug: false,
          flushAt: 2,
          flushInterval: const Duration(hours: 1),
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          requestCount += 1;
          if (!requestStarted.isCompleted) {
            requestStarted.complete();
          }
          await responseGate.future;
          return http.Response(
            jsonEncode({'accepted': 2, 'rejected': 0, 'rejections': []}),
            200,
          );
        }),
      );
      await client.start();

      client.track('first');
      client.track('second');

      await requestStarted.future;
      expect(requestCount, 1);

      responseGate.complete();
      await client.flush();

      expect(client.pendingCount, 0);

      client.dispose();
    });

    test('coalesces concurrent flush requests', () async {
      final requestStarted = Completer<void>();
      final responseGate = Completer<void>();
      var requestCount = 0;
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          environment: 'production',
          debug: false,
          flushInterval: const Duration(hours: 1),
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          requestCount += 1;
          if (!requestStarted.isCompleted) {
            requestStarted.complete();
          }
          await responseGate.future;
          return http.Response(
            jsonEncode({'accepted': 1, 'rejected': 0, 'rejections': []}),
            200,
          );
        }),
      );
      await client.start();
      client.track('feature_used');

      final firstFlush = client.flush();
      final secondFlush = client.flush();
      await requestStarted.future;
      responseGate.complete();
      await Future.wait([firstFlush, secondFlush]);

      expect(requestCount, 1);
      expect(client.pendingCount, 0);

      client.dispose();
    });

    testWidgets('flushInterval sends queued telemetry', (tester) async {
      var requestCount = 0;
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          environment: 'production',
          debug: false,
          flushAt: 100,
          flushInterval: const Duration(milliseconds: 10),
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          requestCount += 1;
          return http.Response(
            jsonEncode({'accepted': 1, 'rejected': 0, 'rejections': []}),
            200,
          );
        }),
      );
      await client.start();

      client.track('feature_used');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();

      expect(requestCount, 1);
      expect(client.pendingCount, 0);

      client.dispose();
    });

    test('keeps retryable failures queued', () async {
      final client = RenaRTK(
        config: config(),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          return http.Response('rate limited', 429);
        }),
      );
      await client.start();

      client.track('feature_used');
      await client.flush();

      expect(client.pendingCount, 1);
    });

    test('drops non-retryable failures', () async {
      final client = RenaRTK(
        config: config(),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        httpClient: MockClient((request) async {
          return http.Response('unauthorized', 401);
        }),
      );
      await client.start();

      client.track('feature_used');
      await client.flush();

      expect(client.pendingCount, 0);
    });

    test('opt-out clears queued items and blocks new telemetry', () async {
      final client = RenaRTK(
        config: config(),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
      );
      await client.start();

      client.track('feature_used');
      await client.setOptOut(true);
      client.track('feature_used');
      client.captureError(StateError('failed'));

      expect(client.pendingCount, 0);

      final restored = RenaRTK(config: config());
      await restored.start();
      restored.track('feature_used');

      expect(restored.isOptedOut, isTrue);
      expect(restored.pendingCount, 0);
    });
  });
}
