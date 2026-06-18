import 'package:flutter/widgets.dart';

typedef RTKFlushCallback = Future<void> Function();
typedef RTKLifecycleCallback = Future<void> Function();

class RTKLifecycleController {
  RTKLifecycleController({
    required this.onFlush,
    this.onResume,
    this.onBackground,
  });

  final RTKFlushCallback onFlush;
  final RTKLifecycleCallback? onResume;
  final RTKLifecycleCallback? onBackground;

  Future<void> handleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await onResume?.call();
        await onFlush();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        await onBackground?.call();
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
