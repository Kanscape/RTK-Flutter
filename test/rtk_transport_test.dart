import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rena_rtk/rena_rtk.dart';
import 'package:rena_rtk/src/rtk_batch.dart';
import 'package:rena_rtk/src/rtk_transport.dart';

void main() {
  RTKConfig config() => RTKConfig(
        endpoint: Uri.parse('https://rena.example.com'),
        publicWriteKey: 'public_test',
        environment: 'production',
      );

  RTKBatch batch() => RTKBatch(
        context: const RTKContext(environment: 'production'),
        anonymousId: 'anon_123',
        sessionId: 'sess_123',
        items: [
          RTKEvent(
              name: 'feature_used', timestamp: DateTime.utc(2026, 6, 10, 12)),
        ],
      );

  group('RTKHttpTransport', () {
    test('posts batch JSON to /v1/batch with Rena auth header', () async {
      http.Request? capturedRequest;
      final transport = RTKHttpTransport(
        config: config(),
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({'accepted': 1, 'rejected': 0, 'rejections': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await transport.send(batch());

      final request = capturedRequest;
      expect(request, isNotNull);
      expect(request!.method, 'POST');
      expect(request.url.toString(), 'https://rena.example.com/v1/batch');
      expect(request.headers['authorization'], 'Rena public_test');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body), batch().toJson());
      expect(result.statusCode, 200);
      expect(result.response?.accepted, 1);
      expect(result.response?.rejected, 0);
      expect(result.shouldRetry, isFalse);
    });

    test('parses item-level rejections', () async {
      final transport = RTKHttpTransport(
        config: config(),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'accepted': 0,
              'rejected': 1,
              'rejections': [
                {
                  'index': 0,
                  'reason': 'property_not_allowed',
                  'field': 'properties.email',
                },
              ],
            }),
            200,
          );
        }),
      );

      final result = await transport.send(batch());

      expect(result.response?.rejections.single.index, 0);
      expect(result.response?.rejections.single.reason, 'property_not_allowed');
      expect(result.response?.rejections.single.field, 'properties.email');
      expect(result.shouldRetry, isFalse);
    });

    test('treats invalid JSON response as retryable failure', () async {
      final transport = RTKHttpTransport(
        config: config(),
        client: MockClient((request) async {
          return http.Response('not-json', 200);
        }),
      );

      final result = await transport.send(batch());

      expect(result.response, isNull);
      expect(result.error, 'invalid_response');
      expect(result.shouldRetry, isTrue);
    });

    test(
      'treats malformed JSON object response as retryable failure',
      () async {
        final transport = RTKHttpTransport(
          config: config(),
          client: MockClient((request) async {
            return http.Response(jsonEncode({'unexpected': true}), 200);
          }),
        );

        final result = await transport.send(batch());

        expect(result.response, isNull);
        expect(result.error, 'invalid_response');
        expect(result.shouldRetry, isTrue);
      },
    );

    test('treats network exceptions as retryable failure', () async {
      final transport = RTKHttpTransport(
        config: config(),
        client: MockClient((request) async {
          throw http.ClientException('offline');
        }),
      );

      final result = await transport.send(batch());

      expect(result.response, isNull);
      expect(result.error, 'network_error');
      expect(result.shouldRetry, isTrue);
    });

    test('treats generic client exceptions as retryable failure', () async {
      final transport = RTKHttpTransport(
        config: config(),
        client: MockClient((request) async {
          throw Exception('offline');
        }),
      );

      final result = await transport.send(batch());

      expect(result.response, isNull);
      expect(result.error, 'network_error');
      expect(result.shouldRetry, isTrue);
    });
  });
}
