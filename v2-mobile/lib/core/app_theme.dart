import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const primary = Color(0xFF0A2C5E);
  static const background = Color(0xFFF0F2F5);
  static const spacing = 16.0;
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary),
    scaffoldBackgroundColor: background,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}
