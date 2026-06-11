import 'rtk_json.dart';

abstract interface class RTKBatchItem {
  Map<String, Object?> toJson();
}

class RTKEvent implements RTKBatchItem {
  RTKEvent({
    required String name,
    required this.timestamp,
    Map<String, Object?>? properties,
  })  : name = name.trim(),
        properties = rtkNormalizeProperties(properties) {
    rtkValidateEventName(name);
  }

  final String name;
  final DateTime timestamp;
  final Map<String, Object?> properties;

  @override
  Map<String, Object?> toJson() {
    return {
      'type': 'event',
      'name': name,
      'timestamp': rtkFormatTimestamp(timestamp),
      'properties': properties,
    };
  }
}
