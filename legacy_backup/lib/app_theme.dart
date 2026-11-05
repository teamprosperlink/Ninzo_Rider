import 'package:flutter/material.dart';

class AppTheme {
  static const brand = Color(0xFFFF8F00);
  static const pickupColor = Color(0xFF2E7D32);
  static const dropColor = Color(0xFFD32F2F);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: brand);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: shape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: shape),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
