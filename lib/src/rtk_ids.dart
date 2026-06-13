import 'dart:convert';
import 'dart:math';

class RTKIdGenerator {
  RTKIdGenerator({int? seed})
      : _random = seed == null ? Random.secure() : Random(seed);

  final Random _random;

  String anonymousId() => 'anon_${_randomToken()}';

  String _randomToken() {
    final bytes = List<int>.generate(18, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
