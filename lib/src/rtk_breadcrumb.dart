import 'rtk_json.dart';

class RTKBreadcrumb {
  RTKBreadcrumb({
    required this.name,
    required this.timestamp,
    Map<String, Object?>? properties,
  }) : properties = rtkNormalizeProperties(properties) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
  }

  final String name;
  final DateTime timestamp;
  final Map<String, Object?> properties;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'timestamp': rtkFormatTimestamp(timestamp),
      'properties': properties,
    };
  }
}
