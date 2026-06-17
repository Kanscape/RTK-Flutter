import 'package:flutter_test/flutter_test.dart';
import 'package:rena_rtk/rena_rtk.dart';
import 'package:rena_rtk/src/rtk_batch.dart';

void main() {
  group('RTK batch JSON', () {
    test('serializes event items for Rena ingest', () {
      final event = RTKEvent(
        name: 'feature_used',
        timestamp: DateTime.utc(2026, 6, 10, 12),
        properties: {'feature': 'search', 'enabled': true},
      );

      expect(event.toJson(), {
        'type': 'event',
        'name': 'feature_used',
        'timestamp': '2026-06-10T12:00:00Z',
        'properties': {'feature': 'search', 'enabled': true},
      });
    });

    test('serializes error items with breadcrumbs', () {
      final error = RTKError(
        errorType: 'NetworkError',
        message: 'Request timeout',
        stack: 'NetworkClient.send',
        timestamp: DateTime.utc(2026, 6, 10, 12, 0, 3),
        properties: {'module': 'sync'},
        breadcrumbs: [
          RTKBreadcrumb(
            name: 'sync_started',
            timestamp: DateTime.utc(2026, 6, 10, 12),
            properties: {'source': 'manual'},
          ),
        ],
      );

      expect(error.toJson(), {
        'type': 'error',
        'error_type': 'NetworkError',
        'message': 'Request timeout',
        'stack': 'NetworkClient.send',
        'timestamp': '2026-06-10T12:00:03Z',
        'properties': {'module': 'sync'},
        'breadcrumbs': [
          {
            'name': 'sync_started',
            'timestamp': '2026-06-10T12:00:00Z',
            'properties': {'source': 'manual'},
          },
        ],
      });
    });

    test('serializes batch without project_id', () {
      final batch = RTKBatch(
        context: const RTKContext(
          platform: 'ios',
          appVersion: '1.0.0',
          buildNumber: '100',
        ),
        anonymousId: 'anon_123',
        items: [
          RTKEvent(
            name: 'feature_used',
            timestamp: DateTime.utc(2026, 6, 10, 12),
          ),
        ],
      );

      final json = batch.toJson();

      expect(json, {
        'context': {
          'platform': 'ios',
          'app_version': '1.0.0',
          'build_number': '100',
        },
        'anonymous_id': 'anon_123',
        'items': [
          {
            'type': 'event',
            'name': 'feature_used',
            'timestamp': '2026-06-10T12:00:00Z',
            'properties': <String, Object?>{},
          },
        ],
      });
      expect(json.containsKey('project_id'), isFalse);
      expect(json.containsKey('session_id'), isFalse);
    });

    test('rejects client-side item limit violations', () {
      expect(
        () =>
            RTKEvent(name: 'x' * 129, timestamp: DateTime.utc(2026, 6, 10, 12)),
        throwsArgumentError,
      );

      expect(
        () => RTKEvent(
          name: 'feature_used',
          timestamp: DateTime.utc(2026, 6, 10, 12),
          properties: {
            for (var index = 0; index < 33; index++) 'property_$index': index,
          },
        ),
        throwsArgumentError,
      );

      expect(
        () => RTKEvent(
          name: 'feature_used',
          timestamp: DateTime.utc(2026, 6, 10, 12),
          properties: {'note': 'x' * 1025},
        ),
        throwsArgumentError,
      );
    });
  });
}
