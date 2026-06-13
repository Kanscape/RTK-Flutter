import 'package:flutter/widgets.dart';

typedef RTKFlushCallback = Future<void> Function();

class RTKLifecycleController {
  RTKLifecycleController({required this.onFlush});

  final RTKFlushCallback onFlush;

  Future<void> handleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await onFlush();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
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
