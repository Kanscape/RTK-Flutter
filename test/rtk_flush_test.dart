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
import 'package:rena_rtk/src/rtk_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  RTKConfig config() => RTKConfig(
        endpoint: Uri.parse('https://rena.example.com'),
        publicWriteKey: 'public_test',
        appVersion: '1.0.0',
        buildNumber: '100',
        runtimePlatform: 'ios',
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
          'app_version': '1.0.0',
          'build_number': '100',
          'locale':
              WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
        });
        expect(body?['anonymous_id'], startsWith('anon_'));
        expect(body?.containsKey('session_id'), isFalse);
        expect(body?['items'], hasLength(2));
        expect((body?['items']! as List).map((item) => item['name']), [
          'app_launch',
          'feature_used',
        ]);
        expect(body?.containsKey('project_id'), isFalse);
      },
    );

    test('fills platform and locale context when config omits them', () async {
      Map<String, Object?>? body;
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
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

    test('fills OS context from device info when config omits it', () async {
      Map<String, Object?>? body;
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          runtimePlatform: 'ios',
          debug: false,
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        deviceInfoProvider: const FakeDeviceInfoProvider(
          osName: 'iOS',
          osVersion: '26.0',
          deviceModel: 'iPhone17,2',
        ),
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

      expect(body?['context'], containsPair('os_name', 'iOS'));
      expect(body?['context'], containsPair('os_version', '26.0'));
      expect(body?['context'], containsPair('device_model', 'iPhone17,2'));

      client.dispose();
    });

    test('manual OS context overrides device info', () async {
      Map<String, Object?>? body;
      final provider = CountingDeviceInfoProvider(
        resolved: const RTKResolvedDeviceInfo(
          osName: 'iOS',
          osVersion: '26.0',
          deviceModel: 'iPhone17,2',
        ),
      );
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          runtimePlatform: 'ios',
          osName: 'ManualOS',
          osVersion: '1.2.3',
          deviceModel: 'ManualDevice',
          debug: false,
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        deviceInfoProvider: provider,
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

      expect(body?['context'], containsPair('os_name', 'ManualOS'));
      expect(body?['context'], containsPair('os_version', '1.2.3'));
      expect(body?['context'], containsPair('device_model', 'ManualDevice'));
      expect(provider.resolveCount, 0);

      client.dispose();
    });

    test('continues when device info provider fails', () async {
      Map<String, Object?>? body;
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          runtimePlatform: 'ios',
          debug: false,
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        deviceInfoProvider: const ThrowingDeviceInfoProvider(),
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
      expect(context.containsKey('os_name'), isFalse);
      expect(context.containsKey('os_version'), isFalse);
      expect(context.containsKey('device_model'), isFalse);

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
          publicWriteKey: 'write_key_for_redaction_1234567890',
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
      expect(output, isNot(contains('write_key_for_redaction_1234567890')));
      final item = (body!['items']! as List<Object?>)
          .cast<Map>()
          .singleWhere((item) => item['name'] == 'feature_used');
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
      expect((body?['items']! as List).map((item) => item['name']), [
        'feature_used',
        'app_launch',
      ]);
    });

    test('sends previous foreground session on next start', () async {
      final storage = await RTKStorage.create();
      await storage.saveForegroundSession(
        RTKForegroundSession(
          startedAt: DateTime.utc(2026, 6, 10, 12),
          lastSeenAt: DateTime.utc(2026, 6, 10, 12, 2),
        ),
      );

      Map<String, Object?>? body;
      final client = RenaRTK(
        config: config(),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12, 5)),
        idGenerator: RTKIdGenerator(seed: 1),
        httpClient: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, Object?>;
          return http.Response(
            jsonEncode({'accepted': 2, 'rejected': 0, 'rejections': []}),
            200,
          );
        }),
      );

      await client.start();
      await client.flush();

      final items =
          (body!['items']! as List<Object?>).cast<Map<String, Object?>>();
      expect(items.map((item) => item['name']), [
        'app_foreground_session',
        'app_launch',
      ]);
      expect(items.first['timestamp'], '2026-06-10T12:02:00Z');
      expect(items.first['properties'], {
        'duration_ms': 120000,
        'started_at': '2026-06-10T12:00:00Z',
        'ended_at': '2026-06-10T12:02:00Z',
        'recovered': true,
      });
      final restoredStorage = await RTKStorage.create();
      final activeSession = await restoredStorage.loadForegroundSession();
      expect(activeSession?.startedAt, DateTime.utc(2026, 6, 10, 12, 5));
      expect(activeSession?.lastSeenAt, DateTime.utc(2026, 6, 10, 12, 5));

      client.dispose();
    });

    test('persists queued telemetry before any flush', () async {
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
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
          debug: false,
          flushAt: 100,
          flushInterval: const Duration(hours: 1),
        ),
      );
      await restored.start();

      expect(restored.pendingCount, 4);

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
          debug: false,
          flushAt: 3,
          flushInterval: const Duration(hours: 1),
        ),
        clock: FakeRTKClock(DateTime.utc(2026, 6, 10, 12)),
        deviceInfoProvider: const FakeDeviceInfoProvider(),
        httpClient: MockClient((request) async {
          requestCount += 1;
          if (!requestStarted.isCompleted) {
            requestStarted.complete();
          }
          await responseGate.future;
          return http.Response(
            jsonEncode({'accepted': 3, 'rejected': 0, 'rejections': []}),
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

    test('flushInterval sends queued telemetry', () async {
      var requestCount = 0;
      final client = RenaRTK(
        config: RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
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
      await waitForCondition(() => requestCount == 1);

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

      expect(client.pendingCount, 2);
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

class FakeDeviceInfoProvider implements RTKDeviceInfoProvider {
  const FakeDeviceInfoProvider({
    this.osName,
    this.osVersion,
    this.deviceModel,
  });

  final String? osName;
  final String? osVersion;
  final String? deviceModel;

  @override
  Future<RTKResolvedDeviceInfo> resolve({required String platform}) async {
    return RTKResolvedDeviceInfo(
      osName: osName,
      osVersion: osVersion,
      deviceModel: deviceModel,
    );
  }
}

class ThrowingDeviceInfoProvider implements RTKDeviceInfoProvider {
  const ThrowingDeviceInfoProvider();

  @override
  Future<RTKResolvedDeviceInfo> resolve({required String platform}) async {
    throw StateError('device info unavailable');
  }
}

class CountingDeviceInfoProvider implements RTKDeviceInfoProvider {
  CountingDeviceInfoProvider({required this.resolved});

  final RTKResolvedDeviceInfo resolved;
  int resolveCount = 0;

  @override
  Future<RTKResolvedDeviceInfo> resolve({required String platform}) async {
    resolveCount += 1;
    return resolved;
  }
}

Future<void> waitForCondition(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
