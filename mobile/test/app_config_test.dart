import 'package:flutter_test/flutter_test.dart';
import 'package:shiftsure_rider/config/app_config.dart';

void main() {
  test('defaults to the local backend', () {
    expect(
      AppConfig.fromEnvironment().apiBaseUrl.toString(),
      AppConfig.defaultApiBaseUrl,
    );
  });

  test('accepts http and https URLs', () {
    expect(AppConfig.parse('http://10.0.2.2:3000').apiBaseUrl.port, 3000);
    expect(
      AppConfig.parse('https://api.example.com').apiBaseUrl.scheme,
      'https',
    );
  });

  test('rejects values that are not absolute http(s) URLs', () {
    for (final bad in ['', 'localhost:3000', 'ftp://x.test', '/health']) {
      expect(() => AppConfig.parse(bad), throwsFormatException, reason: bad);
    }
  });

  test('auth emulator is off by default and configurable', () {
    expect(AppConfig.fromEnvironment().useAuthEmulator, isFalse);
    final c = AppConfig.parse(
      'http://localhost:3000',
      useAuthEmulator: true,
      authEmulatorHost: ' ',
    );
    expect(c.useAuthEmulator, isTrue);
    expect(c.authEmulatorHost, isNull);
    expect(c.authEmulatorPort, 9099);
  });
}
