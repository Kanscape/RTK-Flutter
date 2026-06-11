import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'rtk_batch.dart';
import 'rtk_config.dart';

class RTKItemRejection {
  const RTKItemRejection({
    required this.index,
    required this.reason,
    required this.field,
  });

  factory RTKItemRejection.fromJson(Map<String, Object?> json) {
    return RTKItemRejection(
      index: json['index'] as int,
      reason: json['reason'] as String,
      field: json['field'] as String,
    );
  }

  final int index;
  final String reason;
  final String field;
}

class RTKBatchResponse {
  const RTKBatchResponse({
    required this.accepted,
    required this.rejected,
    required this.rejections,
  });

  factory RTKBatchResponse.fromJson(Map<String, Object?> json) {
    final rejections = json['rejections'] as List<Object?>? ?? const [];
    return RTKBatchResponse(
      accepted: json['accepted'] as int,
      rejected: json['rejected'] as int,
      rejections: [
        for (final rejection in rejections)
          RTKItemRejection.fromJson(rejection! as Map<String, Object?>),
      ],
    );
  }

  static RTKBatchResponse? tryParse(Map<String, Object?> json) {
    try {
      return RTKBatchResponse.fromJson(json);
    } on Object {
      return null;
    }
  }

  final int accepted;
  final int rejected;
  final List<RTKItemRejection> rejections;
}

class RTKTransportResult {
  const RTKTransportResult({
    required this.statusCode,
    required this.response,
    required this.error,
    required this.shouldRetry,
  });

  final int? statusCode;
  final RTKBatchResponse? response;
  final String? error;
  final bool shouldRetry;
}

class RTKHttpTransport {
  RTKHttpTransport({required this.config, http.Client? client})
      : client = client ?? http.Client(),
        _ownsClient = client == null;

  final RTKConfig config;
  final http.Client client;
  final bool _ownsClient;

  Future<RTKTransportResult> send(RTKBatch batch) async {
    try {
      final response = await client
          .post(
            config.batchUri,
            headers: {
              'authorization': 'Rena ${config.publicWriteKey}',
              'content-type': 'application/json',
            },
            body: jsonEncode(batch.toJson()),
          )
          .timeout(config.requestTimeout);

      if (response.statusCode != 200) {
        return RTKTransportResult(
          statusCode: response.statusCode,
          response: null,
          error: 'http_${response.statusCode}',
          shouldRetry: response.statusCode == 429 || response.statusCode >= 500,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        return const RTKTransportResult(
          statusCode: 200,
          response: null,
          error: 'invalid_response',
          shouldRetry: true,
        );
      }

      final batchResponse = RTKBatchResponse.tryParse(decoded);
      if (batchResponse == null) {
        return const RTKTransportResult(
          statusCode: 200,
          response: null,
          error: 'invalid_response',
          shouldRetry: true,
        );
      }

      return RTKTransportResult(
        statusCode: response.statusCode,
        response: batchResponse,
        error: null,
        shouldRetry: false,
      );
    } on TimeoutException {
      return const RTKTransportResult(
        statusCode: null,
        response: null,
        error: 'timeout',
        shouldRetry: true,
      );
    } on http.ClientException {
      return const RTKTransportResult(
        statusCode: null,
        response: null,
        error: 'network_error',
        shouldRetry: true,
      );
    } on FormatException {
      return const RTKTransportResult(
        statusCode: 200,
        response: null,
        error: 'invalid_response',
        shouldRetry: true,
      );
    } on Exception {
      return const RTKTransportResult(
        statusCode: null,
        response: null,
        error: 'network_error',
        shouldRetry: true,
      );
    }
  }

  void close() {
    if (_ownsClient) {
      client.close();
    }
  }
}
