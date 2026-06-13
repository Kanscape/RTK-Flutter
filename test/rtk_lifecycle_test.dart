import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/src/rtk_lifecycle.dart';

void main() {
  group('RTKLifecycleController', () {
    test('paused and detached trigger flush callback', () async {
      var flushCount = 0;
      final controller = RTKLifecycleController(
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
        onFlush: () async {
          flushCount += 1;
        },
      );

      await controller.handleState(AppLifecycleState.resumed);

      expect(flushCount, 1);
    });

    test('state changes do not create identity side effects', () async {
      var flushCount = 0;
      final controller = RTKLifecycleController(
        onFlush: () async {
          flushCount += 1;
        },
      );

      await controller.handleState(AppLifecycleState.paused);
      await controller.handleState(AppLifecycleState.resumed);

      expect(flushCount, 2);
    });
  });
}
