import 'package:flutter/widgets.dart';

import 'rtk_ids.dart';

typedef RTKFlushCallback = Future<void> Function();

class RTKLifecycleController {
  RTKLifecycleController({required this.session, required this.onFlush});

  final RTKSession session;
  final RTKFlushCallback onFlush;

  Future<void> handleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        session.markResumed();
        await onFlush();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        session.markBackgrounded();
        await onFlush();
        return;
    }
  }
}

class RTKLifecycleBinding {
  RTKLifecycleBinding(this.controller)
      : _listener = AppLifecycleListener(
          onStateChange: (state) {
            controller.handleState(state);
          },
        );

  final RTKLifecycleController controller;
  final AppLifecycleListener _listener;

  void dispose() {
    _listener.dispose();
  }
}
