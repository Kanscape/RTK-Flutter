import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'rtk_breadcrumb.dart';
import 'rtk_error.dart';
import 'rtk_event.dart';
import 'rtk_ids.dart';
import 'rtk_queue.dart';

class RTKStorage {
  RTKStorage._(this._preferences, this._idGenerator);

  static const _anonymousIdKey = 'rena_rtk.anonymous_id';
  static const _optOutKey = 'rena_rtk.opt_out';
  static const _queueKey = 'rena_rtk.queue';
  static const _foregroundSessionKey = 'rena_rtk.foreground_session';

  final SharedPreferences _preferences;
  final RTKIdGenerator _idGenerator;

  static Future<RTKStorage> create({RTKIdGenerator? idGenerator}) async {
    return RTKStorage._(
      await SharedPreferences.getInstance(),
      idGenerator ?? RTKIdGenerator(),
    );
  }

  Future<String> anonymousId() async {
    final stored = _preferences.getString(_anonymousIdKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    final generated = _idGenerator.anonymousId();
    await _preferences.setString(_anonymousIdKey, generated);
    return generated;
  }

  Future<bool> isOptedOut() async {
    return _preferences.getBool(_optOutKey) ?? false;
  }

  Future<void> setOptOut(bool value) async {
    await _preferences.setBool(_optOutKey, value);
    if (value) {
      await clearQueue();
      await clearForegroundSession();
    }
  }

  Future<List<RTKQueuedItem>> loadQueue() async {
    final rows = _preferences.getStringList(_queueKey) ?? const [];
    return [
      for (final row in rows)
        _queuedItemFromJson(jsonDecode(row) as Map<String, Object?>),
    ];
  }

  Future<void> saveQueue(List<RTKQueuedItem> items) async {
    await _preferences.setStringList(_queueKey, [
      for (final item in items) jsonEncode(_queuedItemToJson(item)),
    ]);
  }

  Future<void> clearQueue() async {
    await _preferences.remove(_queueKey);
  }

  Future<RTKForegroundSession?> loadForegroundSession() async {
    final row = _preferences.getString(_foregroundSessionKey);
    if (row == null || row.isEmpty) {
      return null;
    }
    return RTKForegroundSession.fromJson(
      Map<String, Object?>.from(jsonDecode(row) as Map),
    );
  }

  Future<void> saveForegroundSession(RTKForegroundSession session) async {
    await _preferences.setString(
      _foregroundSessionKey,
      jsonEncode(session.toJson()),
    );
  }

  Future<void> clearForegroundSession() async {
    await _preferences.remove(_foregroundSessionKey);
  }

  Map<String, Object?> _queuedItemToJson(RTKQueuedItem item) {
    return {
      'item': item.item.toJson(),
      'attempt_count': item.attemptCount,
      if (item.nextRetryAt != null)
        'next_retry_at': item.nextRetryAt!.toUtc().toIso8601String(),
    };
  }

  RTKQueuedItem _queuedItemFromJson(Map<String, Object?> json) {
    return RTKQueuedItem(
      item: _itemFromJson(Map<String, Object?>.from(json['item']! as Map)),
      attemptCount: json['attempt_count'] as int? ?? 0,
      nextRetryAt: json['next_retry_at'] == null
          ? null
          : DateTime.parse(json['next_retry_at']! as String).toUtc(),
    );
  }

  RTKBatchItem _itemFromJson(Map<String, Object?> json) {
    return switch (json['type']) {
      'event' => RTKEvent(
          name: json['name']! as String,
          timestamp: DateTime.parse(json['timestamp']! as String).toUtc(),
          properties: Map<String, Object?>.from(
            json['properties'] as Map? ?? const {},
          ),
        ),
      'error' => RTKError(
          errorType: json['error_type']! as String,
          message: json['message'] as String?,
          stack: json['stack'] as String?,
          timestamp: DateTime.parse(json['timestamp']! as String).toUtc(),
          properties: Map<String, Object?>.from(
            json['properties'] as Map? ?? const {},
          ),
          breadcrumbs: [
            for (final breadcrumb in json['breadcrumbs'] as List? ?? const [])
              _breadcrumbFromJson(Map<String, Object?>.from(breadcrumb as Map)),
          ],
        ),
      _ => throw FormatException('Unknown RTK item type: ${json['type']}'),
    };
  }

  RTKBreadcrumb _breadcrumbFromJson(Map<String, Object?> json) {
    return RTKBreadcrumb(
      name: json['name']! as String,
      timestamp: DateTime.parse(json['timestamp']! as String).toUtc(),
      properties: Map<String, Object?>.from(
        json['properties'] as Map? ?? const {},
      ),
    );
  }
}

class RTKForegroundSession {
  const RTKForegroundSession({
    required this.startedAt,
    required this.lastSeenAt,
  });

  final DateTime startedAt;
  final DateTime lastSeenAt;

  RTKForegroundSession copyWith({
    DateTime? startedAt,
    DateTime? lastSeenAt,
  }) {
    return RTKForegroundSession(
      startedAt: startedAt ?? this.startedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'started_at': startedAt.toUtc().toIso8601String(),
      'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
    };
  }

  factory RTKForegroundSession.fromJson(Map<String, Object?> json) {
    return RTKForegroundSession(
      startedAt: DateTime.parse(json['started_at']! as String).toUtc(),
      lastSeenAt: DateTime.parse(json['last_seen_at']! as String).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RTKForegroundSession &&
        other.startedAt == startedAt &&
        other.lastSeenAt == lastSeenAt;
  }

  @override
  int get hashCode => Object.hash(startedAt, lastSeenAt);
}
