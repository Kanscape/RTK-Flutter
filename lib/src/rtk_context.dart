class RTKContext {
  const RTKContext({
    this.platform,
    this.environment,
    this.appVersion,
    this.buildNumber,
    this.osName,
    this.osVersion,
    this.deviceModel,
    this.locale,
  });

  final String? platform;
  final String? environment;
  final String? appVersion;
  final String? buildNumber;
  final String? osName;
  final String? osVersion;
  final String? deviceModel;
  final String? locale;

  Map<String, Object?> toJson() {
    return {
      if (platform != null) 'platform': platform,
      if (environment != null) 'environment': environment,
      if (appVersion != null) 'app_version': appVersion,
      if (buildNumber != null) 'build_number': buildNumber,
      if (osName != null) 'os_name': osName,
      if (osVersion != null) 'os_version': osVersion,
      if (deviceModel != null) 'device_model': deviceModel,
      if (locale != null) 'locale': locale,
    };
  }
}
