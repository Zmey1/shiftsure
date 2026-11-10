/// Build-time configuration, supplied with `--dart-define` or
/// `--dart-define-from-file` (see `mobile/README.md`).
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    this.useAuthEmulator = false,
    this.authEmulatorHost,
    this.authEmulatorPort = defaultAuthEmulatorPort,
  });

  /// Base URL of the ShiftSure backend, e.g. `http://localhost:3000`.
  final Uri apiBaseUrl;

  /// Use the local Firebase Auth emulator instead of the Firebase development
  /// project (`USE_AUTH_EMULATOR=true`).
  final bool useAuthEmulator;

  /// Emulator host (`AUTH_EMULATOR_HOST`); null picks a platform default
  /// (`10.0.2.2` on Android, `127.0.0.1` elsewhere).
  final String? authEmulatorHost;

  final int authEmulatorPort;

  static const defaultAuthEmulatorPort = 9099;

  static const defaultApiBaseUrl = 'http://localhost:3000';

  // `String.fromEnvironment` only works as a compile-time constant.
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );

  static const _useAuthEmulator = bool.fromEnvironment('USE_AUTH_EMULATOR');
  static const _authEmulatorHost = String.fromEnvironment('AUTH_EMULATOR_HOST');
  static const _authEmulatorPort = int.fromEnvironment(
    'AUTH_EMULATOR_PORT',
    defaultValue: defaultAuthEmulatorPort,
  );

  factory AppConfig.fromEnvironment() => AppConfig.parse(
    _apiBaseUrl,
    useAuthEmulator: _useAuthEmulator,
    authEmulatorHost: _authEmulatorHost,
    authEmulatorPort: _authEmulatorPort,
  );

  /// Parses [apiBaseUrl]; throws [FormatException] if it is not an absolute
  /// http(s) URL, so a misconfigured build fails at startup.
  factory AppConfig.parse(
    String apiBaseUrl, {
    bool useAuthEmulator = false,
    String? authEmulatorHost,
    int authEmulatorPort = defaultAuthEmulatorPort,
  }) {
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
    final host = authEmulatorHost?.trim();
    return AppConfig(
      apiBaseUrl: uri,
      useAuthEmulator: useAuthEmulator,
      authEmulatorHost: host == null || host.isEmpty ? null : host,
      authEmulatorPort: authEmulatorPort,
    );
  }
}
