import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/src/rtk_retry.dart';

void main() {
  group('RTKRetryPolicy', () {
    test('retries rate limit, server, timeout, and network failures', () {
      final policy = RTKRetryPolicy();

      expect(policy.shouldRetry(statusCode: 429), isTrue);
      expect(policy.shouldRetry(statusCode: 500), isTrue);
      expect(policy.shouldRetry(statusCode: 599), isTrue);
      expect(policy.shouldRetry(error: 'timeout'), isTrue);
      expect(policy.shouldRetry(error: 'network_error'), isTrue);
    });

    test('does not retry client, auth, forbidden, or payload failures', () {
      final policy = RTKRetryPolicy();

      expect(policy.shouldRetry(statusCode: 400), isFalse);
      expect(policy.shouldRetry(statusCode: 401), isFalse);
      expect(policy.shouldRetry(statusCode: 403), isFalse);
      expect(policy.shouldRetry(statusCode: 413), isFalse);
    });

    test('calculates capped exponential delay', () {
      final policy = RTKRetryPolicy(
        minDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 10),
      );

      expect(policy.delayForAttempt(0), const Duration(seconds: 1));
      expect(policy.delayForAttempt(1), const Duration(seconds: 2));
      expect(policy.delayForAttempt(2), const Duration(seconds: 4));
      expect(policy.delayForAttempt(10), const Duration(seconds: 10));
    });

    test('stops after max attempts', () {
      final policy = RTKRetryPolicy(maxAttempts: 3);

      expect(policy.canAttempt(0), isTrue);
      expect(policy.canAttempt(2), isTrue);
      expect(policy.canAttempt(3), isFalse);
    });
  });
}
