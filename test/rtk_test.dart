import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/rena_rtk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  RTKConfig config() => RTKConfig(
        endpoint: Uri.parse('https://rena.example.com'),
        publicWriteKey: 'public_test',
        debug: false,
      );

  group('RenaRTK', () {
    test('can be constructed and started more than once', () async {
      final client = RenaRTK(config: config());

      await client.start();
      await client.start();

      expect(client.isStarted, isTrue);
    });

    test('track before start does not throw', () {
      final client = RenaRTK(config: config());

      expect(
        () => client.track('feature_used', properties: {'feature': 'search'}),
        returnsNormally,
      );
    });
  });

  group('RTK', () {
    test('instance before init throws', () {
      expect(() => RTK.instance, throwsStateError);
    });

    test('telemetry calls before init do not throw', () {
      expect(() => RTK.track('feature_used'), returnsNormally);
      expect(() => RTK.captureError(StateError('failed')), returnsNormally);
      expect(() => RTK.addBreadcrumb('launch_started'), returnsNormally);
      expect(
        () => RTK.setSuperProperties({'source': 'startup'}),
        returnsNormally,
      );
      expect(() => RTK.instance, throwsStateError);
    });

    test('flush before init completes without starting the SDK', () async {
      await expectLater(RTK.flush(), completes);

      expect(() => RTK.instance, throwsStateError);
    });

    test('setOptOut before init is applied when initialized', () async {
      await RTK.setOptOut(true);
      await RTK.init(config());

      expect(RTK.instance.isOptedOut, isTrue);
    });

    test('init installs a singleton client', () async {
      await RTK.init(config());

      expect(RTK.instance, isA<RenaRTK>());
      expect(RTK.instance.isStarted, isTrue);
    });
  });
}
