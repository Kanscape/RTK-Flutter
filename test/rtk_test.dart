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
        environment: 'production',
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
    test('init installs a singleton client', () async {
      await RTK.init(config());

      expect(RTK.instance, isA<RenaRTK>());
      expect(RTK.instance.isStarted, isTrue);
    });
  });
}
