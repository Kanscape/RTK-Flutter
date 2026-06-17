import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/rena_rtk.dart';

void main() {
  group('RTKConfig', () {
    test('normalizes endpoint and builds the batch URI', () {
      final config = RTKConfig(
        endpoint: Uri.parse('https://rena.example.com/base/'),
        publicWriteKey: 'public_test',
      );

      expect(config.endpoint.toString(), 'https://rena.example.com/base');
      expect(
        config.batchUri.toString(),
        'https://rena.example.com/base/v1/batch',
      );
    });

    test('rejects empty public write key', () {
      expect(
        () => RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: '  ',
        ),
        throwsArgumentError,
      );
    });

    test('does not expose environment configuration', () {
      final source = File('lib/src/rtk_config.dart').readAsStringSync();

      expect(source, isNot(contains('required String environment')));
      expect(source, isNot(contains('final String environment')));
      expect(source, isNot(contains('this.environment')));
    });

    test('uses SDK defaults from the design document', () {
      final config = RTKConfig(
        endpoint: Uri.parse('https://rena.example.com'),
        publicWriteKey: 'public_test',
      );

      expect(config.enabled, isTrue);
      expect(config.flushAt, 20);
      expect(config.flushInterval, const Duration(seconds: 30));
      expect(config.maxQueueSize, 1000);
      expect(config.maxBreadcrumbs, 50);
      expect(config.requestTimeout, const Duration(seconds: 10));
      expect(config.maxRetryAttempts, 5);
      expect(config.minRetryDelay, const Duration(seconds: 1));
      expect(config.maxRetryDelay, const Duration(seconds: 60));
      expect(config.debug, kDebugMode);
    });

    test('allows debug logging to be disabled explicitly', () {
      final config = RTKConfig(
        endpoint: Uri.parse('https://rena.example.com'),
        publicWriteKey: 'public_test',
        debug: false,
      );

      expect(config.debug, isFalse);
    });

    test('names configured runtime platform separately from SDK family', () {
      final config = RTKConfig(
        endpoint: Uri.parse('https://rena.example.com'),
        publicWriteKey: 'public_test',
        runtimePlatform: 'android',
      );

      expect(config.runtimePlatform, 'android');
    });

    test('does not expose old platform configuration', () {
      final source = File('lib/src/rtk_config.dart').readAsStringSync();

      expect(source, isNot(contains('this.platform')));
      expect(source, isNot(contains('final String? platform')));
      expect(source, isNot(contains('effectiveRuntimePlatform')));
      expect(source, isNot(contains('@Deprecated')));
    });

    test('rejects non-positive timing configuration', () {
      expect(
        () => RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          flushInterval: Duration.zero,
        ),
        throwsArgumentError,
      );

      expect(
        () => RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          requestTimeout: Duration.zero,
        ),
        throwsArgumentError,
      );

      expect(
        () => RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          minRetryDelay: Duration.zero,
        ),
        throwsArgumentError,
      );

      expect(
        () => RTKConfig(
          endpoint: Uri.parse('https://rena.example.com'),
          publicWriteKey: 'public_test',
          minRetryDelay: const Duration(seconds: 10),
          maxRetryDelay: const Duration(seconds: 1),
        ),
        throwsArgumentError,
      );
    });
  });
}
