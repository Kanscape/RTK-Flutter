import 'package:flutter/foundation.dart';

import 'rtk_transport.dart';

class RTKLogger {
  const RTKLogger({required this.enabled});

  final bool enabled;

  void initialized({required Uri endpoint, required String publicWriteKey}) {
    _log(
      'initialized endpoint=$endpoint write_key=${redactSecret(publicWriteKey)}',
    );
  }

  void enqueued({required int pendingCount}) {
    _log('enqueued pending_count=$pendingCount');
  }

  void flushStarted({required String reason, required int pendingCount}) {
    _log('flush_started reason=$reason pending_count=$pendingCount');
  }

  void transportResult({
    required int? statusCode,
    required String? error,
    required bool shouldRetry,
  }) {
    _log(
      'transport_result status_code=${statusCode ?? 'none'} '
      'error=${error ?? 'none'} should_retry=$shouldRetry',
    );
  }

  void batchResponse(RTKBatchResponse response) {
    _log(
      'batch_response accepted=${response.accepted} '
      'rejected=${response.rejected}',
    );
    for (final rejection in response.rejections) {
      _log(
        'item_rejection index=${rejection.index} '
        'field=${rejection.field} reason=${rejection.reason}',
      );
    }
  }

  void retryScheduled({
    required int attemptCount,
    required DateTime nextRetryAt,
  }) {
    _log(
      'retry_scheduled attempt_count=$attemptCount '
      'next_retry_at=${nextRetryAt.toUtc().toIso8601String()}',
    );
  }

  void dropped({required String reason}) {
    _log('dropped reason=$reason');
  }

  void propertyDropped({required String path, required String reason}) {
    _log('dropped_property path=$path reason=$reason');
  }

  void optOutChanged(bool value) {
    _log('opt_out value=$value');
  }

  static String redactSecret(String value) {
    if (value.length <= 10) {
      return '***';
    }
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }

  void _log(String message) {
    if (!enabled) {
      return;
    }
    debugPrint('[rena_rtk] $message');
  }
}
