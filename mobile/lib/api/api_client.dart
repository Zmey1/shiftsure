import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Returns a Firebase ID token, or null when the user is signed out.
typedef TokenProvider = Future<String?> Function();

/// Minimal JSON client for the ShiftSure backend.
///
/// Only `GET` exists today, because the backend only exposes `GET /health`.
/// Add verbs when a feature needs them.
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
  /// `Authorization: Bearer <token>`. Wired to Firebase Auth in a later PR.
  final TokenProvider? tokenProvider;

  final Duration timeout;

  /// GETs [path] (relative to the base URL) and returns the decoded JSON
  /// object. Throws [ApiException] on any failure.
  Future<Map<String, dynamic>> getJson(String path) async {
    final uri = _resolve(path);
    final http.Response response;
    try {
      final token = await tokenProvider?.call();
      response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
          )
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

    final body = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = body?['error'];
      throw ApiException(
        ApiErrorKind.http,
        'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
        code: code is String ? code : null,
      );
    }
    if (body == null) {
      throw const ApiException(
        ApiErrorKind.invalidResponse,
        'Unexpected response from server.',
      );
    }
    return body;
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
