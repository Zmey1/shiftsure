import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'auth/auth_gate.dart';
import 'auth/auth_service.dart';
import 'config/app_config.dart';
import 'theme/app_theme.dart';

class ShiftSureApp extends StatefulWidget {
  const ShiftSureApp({
    super.key,
    required this.config,
    required this.auth,
    this.apiClient,
  });

  final AppConfig config;
  final AuthService auth;

  /// Overridable for tests; defaults to a client for [AppConfig.apiBaseUrl].
  final ApiClient? apiClient;

  @override
  State<ShiftSureApp> createState() => _ShiftSureAppState();
}

class _ShiftSureAppState extends State<ShiftSureApp> {
  late final ApiClient _api =
      widget.apiClient ??
      ApiClient(
        baseUrl: widget.config.apiBaseUrl,
        tokenProvider: widget.auth.getIdToken,
      );

  @override
  void dispose() {
    // Only close a client this widget created itself.
    if (widget.apiClient == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShiftSure',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: AuthGate(auth: widget.auth, api: _api),
    );
  }
}
