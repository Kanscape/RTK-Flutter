import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/src/rtk_ids.dart';

void main() {
  group('RTK IDs', () {
    test('generates anonymous ID prefix', () {
      final ids = RTKIdGenerator();

      expect(ids.anonymousId(), startsWith('anon_'));
    });
  });
}
