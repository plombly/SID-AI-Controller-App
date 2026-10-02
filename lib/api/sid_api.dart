import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/sid_server.dart';
import 'models.dart';

const int supportedApiVersion = 1;

class SidApiException implements Exception {
  const SidApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class SidApi {
  SidApi(SidServer server, {http.Client? client})
    : _server = server,
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  final SidServer _server;
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

  Future<AppInfo> checkCompatible() async {
    final appInfo = await info();
    if (appInfo.minApiVersion > supportedApiVersion) {
      throw SidApiException(
        'This SID server needs a newer app (API version ${appInfo.minApiVersion})',
      );
    }
    if (appInfo.deviceName == null) {
      throw SidApiException(
        "This phone is not paired with ${_server.name}. Pair it again from SID → Settings → Phones & apps.",
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
        throw SidApiException(
          "This phone's key was revoked or is not valid. Pair it again from SID → Settings → Phones & apps.",
          response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SidApiException(
          'SID answered with HTTP ${response.statusCode}',
          response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const SidApiException('SID sent an unexpected answer');
      }
      return Map<String, dynamic>.from(decoded);
    } on SidApiException {
      rethrow;
    } on TimeoutException {
      throw _connectionException();
    } on SocketException {
      throw _connectionException();
    } on http.ClientException {
      throw _connectionException();
    } on FormatException {
      throw const SidApiException('SID sent an unexpected answer');
    }
  }

  SidApiException _connectionException() => SidApiException(
    "Can't reach ${_server.name} at ${_server.url}. Is the VPN connected?",
  );

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
