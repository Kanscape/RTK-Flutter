import 'dart:convert';

const rtkMaxEventNameBytes = 128;
const rtkMaxPropertyCount = 32;
const rtkMaxPropertyStringLength = 1024;

typedef RTKPropertyDropCallback = void Function(String path, String reason);

String rtkFormatTimestamp(DateTime timestamp) {
  final formatted = timestamp.toUtc().toIso8601String();
  return formatted.replaceFirst(RegExp(r'\.000Z$'), 'Z');
}

Map<String, Object?> rtkNormalizeProperties(
  Map<String, Object?>? properties, {
  RTKPropertyDropCallback? onDroppedProperty,
}) {
  if (properties == null) {
    return <String, Object?>{};
  }
  if (properties.length > rtkMaxPropertyCount) {
    throw ArgumentError.value(
      properties.length,
      'properties',
      'must contain at most $rtkMaxPropertyCount entries',
    );
  }

  final normalized = <String, Object?>{};
  for (final entry in properties.entries) {
    final value = _normalizeJsonValue(
      entry.value,
      entry.key,
      onDroppedProperty,
    );
    if (!identical(value, _skippedValue)) {
      normalized[entry.key] = value;
    }
  }
  return normalized;
}

void rtkValidateEventName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be empty');
  }
  if (utf8.encode(trimmed).length > rtkMaxEventNameBytes) {
    throw ArgumentError.value(
      name,
      'name',
      'must be at most $rtkMaxEventNameBytes bytes',
    );
  }
}

Object? _normalizeJsonValue(
  Object? value,
  String path,
  RTKPropertyDropCallback? onDroppedProperty,
) {
  switch (value) {
    case null:
    case bool():
    case num():
      return value;
    case String():
      if (value.length > rtkMaxPropertyStringLength) {
        throw ArgumentError.value(
          value,
          'properties',
          'string values must be at most $rtkMaxPropertyStringLength characters',
        );
      }
      return value;
    case Iterable<Object?>():
      final values = <Object?>[];
      var index = 0;
      for (final item in value) {
        final normalized = _normalizeJsonValue(
          item,
          '$path[$index]',
          onDroppedProperty,
        );
        if (!identical(normalized, _skippedValue)) {
          values.add(normalized);
        }
        index += 1;
      }
      return values;
    case Map<String, Object?>():
      final values = <String, Object?>{};
      for (final entry in value.entries) {
        final normalized = _normalizeJsonValue(
          entry.value,
          '$path.${entry.key}',
          onDroppedProperty,
        );
        if (!identical(normalized, _skippedValue)) {
          values[entry.key] = normalized;
        }
      }
      return values;
    default:
      onDroppedProperty?.call(path, 'unsupported_value');
      return _skippedValue;
  }
}

const _skippedValue = Object();
