import 'package:flutter/material.dart';

import '../design/rider_tokens.dart';

class AppTheme {
  /// Map pin colours.
  static const restaurantColor = RiderColors.brand;
  static const customerColor = RiderColors.error;
  static const onTimeColor = RiderColors.brand;
  static const lateColor = RiderColors.error;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: RiderColors.brand,
      primary: RiderColors.brand,
      onPrimary: RiderColors.white,
      error: RiderColors.error,
      surface: RiderColors.screen,
      onSurface: RiderColors.ink,
    );
    final text = TextTheme(
      displaySmall: RiderText.displayXl,
      headlineMedium: RiderText.h4,
      titleLarge: RiderText.subheadingMedium,
      titleMedium: RiderText.subheadingSmall,
      titleSmall: RiderText.labelLarge,
      bodyLarge: RiderText.bodyLarge,
      bodyMedium: RiderText.bodyMedium,
      bodySmall: RiderText.caption,
      labelLarge: RiderText.button,
      labelMedium: RiderText.labelMedium,
      labelSmall: RiderText.labelSmall,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Inter',
      textTheme: text,
      scaffoldBackgroundColor: RiderColors.screen,
      dividerTheme: const DividerThemeData(color: RiderColors.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: RiderColors.screen,
        foregroundColor: RiderColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: RiderText.subheadingMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          backgroundColor: RiderColors.brand,
          disabledBackgroundColor: RiderColors.brandDisabled,
          disabledForegroundColor: RiderColors.white,
          textStyle: RiderText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          foregroundColor: RiderColors.brand,
          side: const BorderSide(color: RiderColors.brand, width: 1.5),
          textStyle: RiderText.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: RiderColors.grey, textStyle: RiderText.button),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RiderColors.overlay,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(RiderRadius.card), borderSide: BorderSide.none),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: RiderColors.brand),
    );
  }
}
