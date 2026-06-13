import 'package:device_info_plus/device_info_plus.dart';

class RTKResolvedDeviceInfo {
  const RTKResolvedDeviceInfo({
    this.osName,
    this.osVersion,
    this.deviceModel,
  });

  final String? osName;
  final String? osVersion;
  final String? deviceModel;
}

abstract class RTKDeviceInfoProvider {
  Future<RTKResolvedDeviceInfo> resolve({required String platform});
}

class RTKDefaultDeviceInfoProvider implements RTKDeviceInfoProvider {
  RTKDefaultDeviceInfoProvider({
    DeviceInfoPlugin? plugin,
    this.timeout = const Duration(milliseconds: 500),
  }) : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;
  final Duration timeout;

  @override
  Future<RTKResolvedDeviceInfo> resolve({required String platform}) {
    return _resolve(platform.toLowerCase()).timeout(
      timeout,
      onTimeout: () => const RTKResolvedDeviceInfo(),
    );
  }

  Future<RTKResolvedDeviceInfo> _resolve(String platform) async {
    return switch (platform) {
      'android' => await _androidInfo(),
      'ios' => await _iosInfo(),
      _ => const RTKResolvedDeviceInfo(),
    };
  }

  Future<RTKResolvedDeviceInfo> _androidInfo() async {
    final info = await _plugin.androidInfo;
    return RTKResolvedDeviceInfo(
      osName: 'Android',
      osVersion: _nonEmpty(info.version.release),
      deviceModel: _nonEmpty(info.model),
    );
  }

  Future<RTKResolvedDeviceInfo> _iosInfo() async {
    final info = await _plugin.iosInfo;
    return RTKResolvedDeviceInfo(
      osName: _nonEmpty(info.systemName) ?? 'iOS',
      osVersion: _nonEmpty(info.systemVersion),
      deviceModel: _nonEmpty(info.utsname.machine) ?? _nonEmpty(info.model),
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
