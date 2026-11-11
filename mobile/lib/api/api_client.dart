import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Returns a Firebase ID token, or null when the user is signed out.
typedef TokenProvider = Future<String?> Function();

/// Minimal JSON client for the ShiftSure backend.
class ApiClient {
  ApiClient({
    required this._baseUrl,
    http.Client? client,
    this.tokenProvider,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final Uri _baseUrl;
  final http.Client _client;

  /// When set and it returns a token, requests carry
  /// `Authorization: Bearer <token>`. The app wires this to Firebase Auth.
  final TokenProvider? tokenProvider;

  final Duration timeout;

  /// GETs [path] (relative to the base URL) and returns the decoded JSON
  /// object. Throws [ApiException] on any failure.
  Future<Map<String, dynamic>> getJson(String path) => _send('GET', path);

  /// POSTs [body] as JSON. Same return and error behaviour as [getJson].
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) => _send('POST', path, body: body);

  /// PATCHes [body] as JSON. Same return and error behaviour as [getJson].
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) => _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _resolve(path);
    final http.Response response;
    try {
      final token = await tokenProvider?.call();
      final request = http.Request(method, uri)
        ..headers.addAll({
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        });
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        ApiErrorKind.timeout,
        'The server took too long to respond.',
      );
    } on SocketException {
      throw const ApiException(
        ApiErrorKind.network,
        'Could not reach the server.',
      );
    } on http.ClientException {
      throw const ApiException(
        ApiErrorKind.network,
        'Could not reach the server.',
      );
    }

    final decoded = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = decoded?['error'];
      throw ApiException(
        ApiErrorKind.http,
        'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
        code: code is String ? code : null,
        body: decoded,
      );
    }
    if (decoded == null) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Unexpected response from server.',
      );
    }
    return decoded;
  }

  void close() => _client.close();

  Uri _resolve(String path) {
    final base = _baseUrl.path.endsWith('/')
        ? _baseUrl.path.substring(0, _baseUrl.path.length - 1)
        : _baseUrl.path;
    final rel = path.startsWith('/') ? path : '/$path';
    return _baseUrl.replace(path: '$base$rel');
  }

  static Map<String, dynamic>? _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
