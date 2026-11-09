import 'package:flutter/material.dart';

/// Material 3 themes seeded from the indigo of the earlier ShiftSure design.
class AppTheme {
  const AppTheme._();

  static const _seed = Color(0xFF6366F1);
  static const _secondary = Color(0xFFF59E0B);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      secondary: _secondary,
      brightness: brightness,
    );
    return ThemeData(useMaterial3: true, colorScheme: scheme);
  }
}
