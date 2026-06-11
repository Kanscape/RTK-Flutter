import 'rtk_breadcrumb.dart';
import 'rtk_event.dart';
import 'rtk_json.dart';

class RTKError implements RTKBatchItem {
  RTKError({
    required String errorType,
    required this.timestamp,
    this.message,
    this.stack,
    Map<String, Object?>? properties,
    List<RTKBreadcrumb> breadcrumbs = const [],
  })  : errorType = errorType.trim(),
        properties = rtkNormalizeProperties(properties),
        breadcrumbs = List.unmodifiable(breadcrumbs) {
    if (this.errorType.isEmpty) {
      throw ArgumentError.value(errorType, 'errorType', 'must not be empty');
    }
  }

  final String errorType;
  final String? message;
  final String? stack;
  final DateTime timestamp;
  final Map<String, Object?> properties;
  final List<RTKBreadcrumb> breadcrumbs;

  @override
  Map<String, Object?> toJson() {
    return {
      'type': 'error',
      'error_type': errorType,
      if (message != null) 'message': message,
      if (stack != null) 'stack': stack,
      'timestamp': rtkFormatTimestamp(timestamp),
      'properties': properties,
      'breadcrumbs':
          breadcrumbs.map((breadcrumb) => breadcrumb.toJson()).toList(),
    };
  }
}
