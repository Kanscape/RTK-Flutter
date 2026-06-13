import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/src/rtk_logger.dart';

void main() {
  group('RTKLogger', () {
    late DebugPrintCallback originalDebugPrint;
    late List<String> messages;

    setUp(() {
      originalDebugPrint = debugPrint;
      messages = <String>[];
      debugPrint = (String? message, {int? wrapWidth}) {
        messages.add(message ?? '');
      };
    });

    tearDown(() {
      debugPrint = originalDebugPrint;
    });

    test('redacts public write key in debug output', () {
      const writeKey = 'write_key_for_redaction_1234567890';
      final logger = RTKLogger(enabled: true);

      logger.initialized(
        endpoint: Uri.parse('https://rena.example.com'),
        publicWriteKey: writeKey,
      );

      final output = messages.join('\n');
      expect(output, contains('write_...7890'));
      expect(output, isNot(contains(writeKey)));
    });

    test('does not print when disabled', () {
      final logger = RTKLogger(enabled: false);

      logger.optOutChanged(true);

      expect(messages, isEmpty);
    });
  });
}
