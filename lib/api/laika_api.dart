import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/laika_server.dart';
import 'models.dart';

const int supportedApiVersion = 1;

String newRequestId() {
  const characters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random.secure();
  return List<String>.generate(
    24,
    (_) => characters[random.nextInt(characters.length)],
  ).join();
}

class LaikaApiException implements Exception {
  const LaikaApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class LaikaApi {
  LaikaApi(LaikaServer server, {http.Client? client})
    : _server = server,
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  final LaikaServer _server;
  final http.Client _client;
  final bool _ownsClient;

  Future<AppInfo> info() async {
    final json = await _getJson('/api/app/info');
    return AppInfo.fromJson(json);
  }

  Future<Summary> summary() async {
    final json = await _getJson('/api/app/summary');
    return Summary.fromJson(json);
  }

  Future<ProjectDetail> project(String id) async => ProjectDetail.fromJson(
    await _getJsonPath(<String>['api', 'projects', id], {'limit': '25'}),
  );

  Future<String> submitGoal(
    String projectId,
    String goal, {
    bool atomic = false,
  }) async {
    final json = await _postJson(
      <String>['api', 'projects', projectId, 'goals'],
      {'goal': goal, 'atomic': atomic, 'request_id': newRequestId()},
    );
    return json['id'] is String ? json['id'] as String : '';
  }

  Future<AssistantSession> startAssistant(
    String projectId,
    String idea,
  ) async => AssistantSession.fromJson(
    await _postJson(
      <String>['api', 'projects', projectId, 'assistant'],
      {'idea': idea},
    ),
  );

  Future<AssistantSession> assistant(String sessionId) async =>
      AssistantSession.fromJson(
        await _getJsonPath(<String>['api', 'assistant', sessionId]),
      );

  Future<AssistantSession> answerAssistant(
    String sessionId,
    List<String> answers,
  ) async => AssistantSession.fromJson(
    await _postJson(
      <String>['api', 'assistant', sessionId, 'reply'],
      {'answers': answers},
    ),
  );

  Future<AssistantSession> reviseAssistant(
    String sessionId,
    String feedback,
  ) async => AssistantSession.fromJson(
    await _postJson(
      <String>['api', 'assistant', sessionId, 'reply'],
      {'feedback': feedback},
    ),
  );

  Future<String> submitAssistant(
    String sessionId,
    String goal, {
    required bool atomic,
  }) async {
    final json = await _postJson(
      <String>['api', 'assistant', sessionId, 'submit'],
      {'goal': goal, 'atomic': atomic, 'request_id': newRequestId()},
    );
    return json['id'] is String ? json['id'] as String : '';
  }

  Future<AssistantSession> cancelAssistant(String sessionId) async =>
      AssistantSession.fromJson(
        await _postJson(<String>['api', 'assistant', sessionId, 'cancel'], {}),
      );

  Future<void> jobAction(
    String jobId,
    String action, {
    String expectedStatus = 'needs_human',
  }) async {
    try {
      final baseUrl = _server.url.replaceFirst(RegExp(r'/+$'), '');
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/jobs/$jobId/actions'),
            headers: {
              'Authorization': 'Bearer ${_server.key}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'action': action,
              'request_id': newRequestId(),
              'expected_status': expectedStatus,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        throw LaikaApiException(
          "This phone's key was revoked or is not valid. Pair it again from LAIka → Settings → Phones & apps.",
          response.statusCode,
        );
      }
      if (response.statusCode == 403 || response.statusCode == 409) {
        String? detail;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] is String) {
            detail = decoded['detail'] as String;
          }
        } on FormatException {
          // Fall through to the safe HTTP fallback.
        }
        throw LaikaApiException(
          detail ?? 'LAIka answered with HTTP ${response.statusCode}',
          response.statusCode,
        );
      }
      if (response.statusCode != 202) {
        throw LaikaApiException(
          'LAIka answered with HTTP ${response.statusCode}',
          response.statusCode,
        );
      }
    } on LaikaApiException {
      rethrow;
    } on TimeoutException {
      throw _connectionException();
    } on SocketException {
      throw _connectionException();
    } on http.ClientException {
      throw _connectionException();
    }
  }

  Future<AppInfo> checkCompatible() async {
    final appInfo = await info();
    if (appInfo.minApiVersion > supportedApiVersion) {
      throw LaikaApiException(
        'This LAIka server needs a newer app (API version ${appInfo.minApiVersion})',
      );
    }
    if (appInfo.deviceName == null) {
      throw LaikaApiException(
        "This phone is not paired with ${_server.name}. Pair it again from LAIka → Settings → Phones & apps.",
      );
    }
    return appInfo;
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    try {
      final baseUrl = _server.url.replaceFirst(RegExp(r'/+$'), '');
      final response = await _client
          .get(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Authorization': 'Bearer ${_server.key}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        if (response.statusCode == 403) {
          throw _responseException(response);
        }
        throw LaikaApiException(
          "This phone's key was revoked or is not valid. Pair it again from LAIka → Settings → Phones & apps.",
          response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LaikaApiException(
          'LAIka answered with HTTP ${response.statusCode}',
          response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const LaikaApiException('LAIka sent an unexpected answer');
      }
      return Map<String, dynamic>.from(decoded);
    } on LaikaApiException {
      rethrow;
    } on TimeoutException {
      throw _connectionException();
    } on SocketException {
      throw _connectionException();
    } on http.ClientException {
      throw _connectionException();
    } on FormatException {
      throw const LaikaApiException('LAIka sent an unexpected answer');
    }
  }

  Future<Map<String, dynamic>> _getJsonPath(
    List<String> segments, [
    Map<String, String>? queryParameters,
  ]) async {
    return _requestJson(_uri(segments, queryParameters), method: 'GET');
  }

  Future<Map<String, dynamic>> _postJson(
    List<String> segments,
    Map<String, dynamic> body,
  ) async => _requestJson(_uri(segments), method: 'POST', body: body);

  Uri _uri(List<String> segments, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(_server.url.replaceFirst(RegExp(r'/+$'), ''));
    return base.replace(
      pathSegments: <String>[...base.pathSegments, ...segments],
      queryParameters: queryParameters,
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    Uri uri, {
    required String method,
    Map<String, dynamic>? body,
  }) async {
    try {
      final response =
          await (method == 'GET'
                  ? _client.get(
                      uri,
                      headers: {
                        'Authorization': 'Bearer ${_server.key}',
                        'Accept': 'application/json',
                      },
                    )
                  : _client.post(
                      uri,
                      headers: {
                        'Authorization': 'Bearer ${_server.key}',
                        'Content-Type': 'application/json',
                        'Accept': 'application/json',
                      },
                      body: jsonEncode(body ?? <String, dynamic>{}),
                    ))
              .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401) {
        throw LaikaApiException(
          "This phone's key was revoked or is not valid. Pair it again from LAIka → Settings → Phones & apps.",
          response.statusCode,
        );
      }
      if (response.statusCode == 403 ||
          response.statusCode == 409 ||
          response.statusCode == 422 ||
          response.statusCode == 429) {
        throw _responseException(response);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LaikaApiException(
          'LAIka answered with HTTP ${response.statusCode}',
          response.statusCode,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const LaikaApiException('LAIka sent an unexpected answer');
      }
      return Map<String, dynamic>.from(decoded);
    } on LaikaApiException {
      rethrow;
    } on TimeoutException {
      throw _connectionException();
    } on SocketException {
      throw _connectionException();
    } on http.ClientException {
      throw _connectionException();
    } on FormatException {
      throw const LaikaApiException('LAIka sent an unexpected answer');
    }
  }

  LaikaApiException _responseException(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] is String) {
        return LaikaApiException(
          decoded['detail'] as String,
          response.statusCode,
        );
      }
    } on FormatException {
      // Fall through to the safe HTTP fallback.
    }
    return LaikaApiException(
      'LAIka answered with HTTP ${response.statusCode}',
      response.statusCode,
    );
  }

  LaikaApiException _connectionException() => LaikaApiException(
    "Can't reach ${_server.name} at ${_server.url}. Is the VPN connected?",
  );

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
