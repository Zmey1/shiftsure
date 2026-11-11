enum ApiErrorKind {
  /// Could not reach the server (offline, wrong host, connection refused).
  network,

  /// No response within the client timeout.
  timeout,

  /// The server answered with a non-2xx status.
  http,

  /// A 2xx response whose body was not the expected JSON.
  invalidResponse,
}

class ApiException implements Exception {
  const ApiException(
    this.kind,
    this.message, {
    this.statusCode,
    this.code,
    this.body,
  });

  final ApiErrorKind kind;

  /// Short, user-presentable description. Never contains tokens.
  final String message;

  /// HTTP status, for [ApiErrorKind.http].
  final int? statusCode;

  /// Machine-readable `error` value from the backend body
  /// (e.g. `unauthenticated`, `forbidden`), when present.
  final String? code;

  /// The decoded JSON error body, when present (e.g. per-field
  /// `validation_failed` details).
  final Map<String, dynamic>? body;

  @override
  String toString() => 'ApiException(${kind.name}): $message';
}
