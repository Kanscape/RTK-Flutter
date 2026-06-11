import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/src/rtk_clock.dart';
import 'package:rena_rtk/src/rtk_ids.dart';

void main() {
  group('RTK IDs', () {
    test('generates anonymous and session prefixes', () {
      final ids = RTKIdGenerator();

      expect(ids.anonymousId(), startsWith('anon_'));
      expect(ids.sessionId(), startsWith('sess_'));
    });
  });

  group('RTKSession', () {
    test('renews session after 30 minutes in background', () {
      final clock = FakeRTKClock(DateTime.utc(2026, 6, 10, 12));
      final session = RTKSession(
        clock: clock,
        idGenerator: RTKIdGenerator(seed: 1),
      );
      final firstId = session.currentId;

      session.markBackgrounded();
      clock.nowValue = DateTime.utc(2026, 6, 10, 12, 31);
      session.markResumed();

      expect(session.currentId, isNot(firstId));
      expect(session.currentId, startsWith('sess_'));
    });

    test('keeps session when background duration is under 30 minutes', () {
      final clock = FakeRTKClock(DateTime.utc(2026, 6, 10, 12));
      final session = RTKSession(
        clock: clock,
        idGenerator: RTKIdGenerator(seed: 1),
      );
      final firstId = session.currentId;

      session.markBackgrounded();
      clock.nowValue = DateTime.utc(2026, 6, 10, 12, 29, 59);
      session.markResumed();

      expect(session.currentId, firstId);
    });
  });
}
