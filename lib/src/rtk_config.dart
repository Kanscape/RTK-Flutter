import 'package:flutter/foundation.dart';

import 'rtk_event.dart';

typedef RTKBeforeSend = RTKBatchItem? Function(RTKBatchItem item);

class RTKConfig {
  RTKConfig({
    required Uri endpoint,
    required String publicWriteKey,
    required String environment,
    this.appVersion,
    this.buildNumber,
    this.runtimePlatform,
    this.osName,
    this.osVersion,
    this.deviceModel,
    this.locale,
    this.debug = kDebugMode,
    this.enabled = true,
    this.flushAt = 20,
    this.flushInterval = const Duration(seconds: 30),
    this.maxQueueSize = 1000,
    this.maxBreadcrumbs = 50,
    this.requestTimeout = const Duration(seconds: 10),
    this.maxRetryAttempts = 5,
    this.minRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 60),
    this.beforeSend,
  })  : endpoint = _normalizeEndpoint(endpoint),
        publicWriteKey = publicWriteKey.trim(),
        environment = environment.trim() {
    if (this.endpoint.toString().isEmpty) {
      throw ArgumentError.value(endpoint, 'endpoint', 'must not be empty');
    }
    if (this.publicWriteKey.isEmpty) {
      throw ArgumentError.value(
        publicWriteKey,
        'publicWriteKey',
        'must not be empty',
      );
    }
    if (this.environment.isEmpty) {
      throw ArgumentError.value(
        environment,
        'environment',
        'must not be empty',
      );
    }
    if (flushAt <= 0) {
      throw ArgumentError.value(flushAt, 'flushAt', 'must be positive');
    }
    if (maxQueueSize <= 0) {
      throw ArgumentError.value(
        maxQueueSize,
        'maxQueueSize',
        'must be positive',
      );
    }
    if (maxBreadcrumbs <= 0) {
      throw ArgumentError.value(
        maxBreadcrumbs,
        'maxBreadcrumbs',
        'must be positive',
      );
    }
    if (maxRetryAttempts < 0) {
      throw ArgumentError.value(
        maxRetryAttempts,
        'maxRetryAttempts',
        'must not be negative',
      );
    }
    _validatePositiveDuration(flushInterval, 'flushInterval');
    _validatePositiveDuration(requestTimeout, 'requestTimeout');
    _validatePositiveDuration(minRetryDelay, 'minRetryDelay');
    _validatePositiveDuration(maxRetryDelay, 'maxRetryDelay');
    if (maxRetryDelay < minRetryDelay) {
      throw ArgumentError.value(
        maxRetryDelay,
        'maxRetryDelay',
        'must be greater than or equal to minRetryDelay',
      );
    }
  }

  final Uri endpoint;
  final String publicWriteKey;
  final String environment;
  final String? appVersion;
  final String? buildNumber;
  final String? runtimePlatform;
  final String? osName;
  final String? osVersion;
  final String? deviceModel;
  final String? locale;
  final bool debug;
  final bool enabled;
  final int flushAt;
  final Duration flushInterval;
  final int maxQueueSize;
  final int maxBreadcrumbs;
  final Duration requestTimeout;
  final int maxRetryAttempts;
  final Duration minRetryDelay;
  final Duration maxRetryDelay;
  final RTKBeforeSend? beforeSend;

  Uri get batchUri =>
      endpoint.replace(path: _appendPath(endpoint.path, 'v1/batch'));

  static Uri _normalizeEndpoint(Uri endpoint) {
    final value = endpoint.toString().trim();
    if (value.isEmpty) {
      return endpoint;
    }
    return Uri.parse(value.replaceFirst(RegExp(r'/+$'), ''));
  }

  static String _appendPath(String basePath, String suffix) {
    final normalizedBase = basePath.replaceFirst(RegExp(r'/+$'), '');
    if (normalizedBase.isEmpty) {
      return '/$suffix';
    }
    return '$normalizedBase/$suffix';
  }

  static void _validatePositiveDuration(Duration value, String name) {
    if (value.inMicroseconds <= 0) {
      throw ArgumentError.value(value, name, 'must be positive');
    }
  }
}
