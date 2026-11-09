/// Build-time configuration, supplied with `--dart-define` or
/// `--dart-define-from-file` (see `mobile/README.md`).
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// Base URL of the ShiftSure backend, e.g. `http://localhost:3000`.
  final Uri apiBaseUrl;

  static const defaultApiBaseUrl = 'http://localhost:3000';

  // `String.fromEnvironment` only works as a compile-time constant.
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );

  factory AppConfig.fromEnvironment() => AppConfig.parse(_apiBaseUrl);

  /// Parses [apiBaseUrl]; throws [FormatException] if it is not an absolute
  /// http(s) URL, so a misconfigured build fails at startup.
  factory AppConfig.parse(String apiBaseUrl) {
    final uri = Uri.tryParse(apiBaseUrl.trim());
    final valid =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!valid) {
      throw FormatException(
        'API_BASE_URL must be an absolute http(s) URL',
        apiBaseUrl,
      );
    }
    return AppConfig(apiBaseUrl: uri);
  }
}
