import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/src/rtk_clock.dart';
import 'package:rena_rtk/src/rtk_ids.dart';
import 'package:rena_rtk/src/rtk_lifecycle.dart';

void main() {
  group('RTKLifecycleController', () {
    test('paused and detached trigger flush callback', () async {
      var flushCount = 0;
      final controller = RTKLifecycleController(
        session: RTKSession(),
        onFlush: () async {
          flushCount += 1;
        },
      );

      await controller.handleState(AppLifecycleState.paused);
      await controller.handleState(AppLifecycleState.detached);

      expect(flushCount, 2);
    });

    test('resumed triggers flush callback', () async {
      var flushCount = 0;
      final controller = RTKLifecycleController(
        session: RTKSession(),
        onFlush: () async {
          flushCount += 1;
        },
      );

      await controller.handleState(AppLifecycleState.resumed);

      expect(flushCount, 1);
    });

    test('resumed after timeout renews session', () async {
      final clock = FakeRTKClock(DateTime.utc(2026, 6, 10, 12));
      final session = RTKSession(
        clock: clock,
        idGenerator: RTKIdGenerator(seed: 1),
      );
      final firstId = session.currentId;
      final controller = RTKLifecycleController(
        session: session,
        onFlush: () async {},
      );

      await controller.handleState(AppLifecycleState.paused);
      clock.nowValue = DateTime.utc(2026, 6, 10, 12, 31);
      await controller.handleState(AppLifecycleState.resumed);

      expect(session.currentId, isNot(firstId));
    });
  });
}
