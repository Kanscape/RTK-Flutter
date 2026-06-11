import 'dart:convert';
import 'dart:math';

import 'rtk_clock.dart';

class RTKIdGenerator {
  RTKIdGenerator({int? seed})
      : _random = seed == null ? Random.secure() : Random(seed);

  final Random _random;

  String anonymousId() => 'anon_${_randomToken()}';

  String sessionId() => 'sess_${_randomToken()}';

  String _randomToken() {
    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}

class RTKSession {
  RTKSession({
    this.clock = const RTKClock(),
    RTKIdGenerator? idGenerator,
    this.timeout = const Duration(minutes: 30),
  }) : _idGenerator = idGenerator ?? RTKIdGenerator() {
    _currentId = _idGenerator.sessionId();
  }

  final RTKClock clock;
  final RTKIdGenerator _idGenerator;
  final Duration timeout;

  late String _currentId;
  DateTime? _backgroundedAt;

  String get currentId => _currentId;

  void markBackgrounded() {
    _backgroundedAt = clock.now();
  }

  void markResumed() {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;
    if (backgroundedAt == null) {
      return;
    }
    if (clock.now().difference(backgroundedAt) >= timeout) {
      _currentId = _idGenerator.sessionId();
    }
  }
}
