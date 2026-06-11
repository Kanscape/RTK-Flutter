class RTKRetryPolicy {
  const RTKRetryPolicy({
    this.maxAttempts = 5,
    this.minDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 60),
  });

  final int maxAttempts;
  final Duration minDelay;
  final Duration maxDelay;

  bool canAttempt(int attemptCount) {
    return attemptCount < maxAttempts;
  }

  bool shouldRetry({int? statusCode, String? error}) {
    if (error == 'timeout' ||
        error == 'network_error' ||
        error == 'invalid_response') {
      return true;
    }
    if (statusCode == null) {
      return false;
    }
    return statusCode == 429 || statusCode >= 500;
  }

  Duration delayForAttempt(int attemptCount) {
    final multiplier = 1 << attemptCount.clamp(0, 30);
    final milliseconds = minDelay.inMilliseconds * multiplier;
    if (milliseconds >= maxDelay.inMilliseconds) {
      return maxDelay;
    }
    return Duration(milliseconds: milliseconds);
  }
}
