import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

export '../constants/app_colors.dart';

/// Text styles from the Figma type scale. All Inter.
abstract final class RiderText {
  // One-off styles from the Figma frames.
  /// Onboard 01's title.
  static final splashTitle = displayXl.copyWith(color: RiderColors.white, fontSize: 44, height: 52 / 44, letterSpacing: -1);

  /// The big number on the hero art.
  static final heroNumber = displayXl.copyWith(color: RiderColors.white, fontSize: 60, height: 68 / 60);

  /// The country flag in the phone field.
  static final phoneFlag = bodyMedium.copyWith(fontSize: 12.5, height: 20 / 12.5);

  /// Login's emphasised number.
  static final bodyMediumSemibold = bodyMedium.copyWith(fontWeight: FontWeight.w600);

  /// The stopwatch emoji on Restock.
  static const timerGlyph = TextStyle(fontSize: 20, height: 26 / 20);

  /// Input text and titles on a 20 px line.
  static final bodyLargeTight = bodyLarge.copyWith(height: 20 / 16);
  static final labelLargeTight = labelLarge.copyWith(height: 20 / 14);

  static final overlineSpaced1_2 = overline.copyWith(letterSpacing: 1.2);
  static final overlineSpaced1_4 = overline.copyWith(letterSpacing: 1.4);
  static final overlineSpaced2 = overline.copyWith(letterSpacing: 2);

  static const _family = 'Inter';

  static TextStyle _s(double size, double height, FontWeight weight, double spacing, [Color color = RiderColors.ink]) =>
      TextStyle(
        fontFamily: _family,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: spacing,
        color: color,
      );

  /// Display/2XL: 36/48 ExtraBold (lock-screen clock, Notification 05–07).
  static final display2xl = _s(36, 48, FontWeight.w800, 0.5);

  /// Display/XL: 32/40 SemiBold.
  static final displayXl = _s(32, 40, FontWeight.w600, 0.25);

  /// Heading/H3: 32/40 SemiBold.
  static final h3 = _s(32, 40, FontWeight.w600, 0.15);

  /// Heading/H4: 28/36 Medium.
  static final h4 = _s(28, 36, FontWeight.w500, 0);

  /// Metric/Large: 32/40 Bold, -0.5.
  static final metricLarge = _s(32, 40, FontWeight.w700, -0.5);

  /// Subheading/Medium: 18/28 SemiBold.
  static final subheadingMedium = _s(18, 28, FontWeight.w600, 0);

  /// Subheading/Small: 16/24 Medium.
  static final subheadingSmall = _s(16, 24, FontWeight.w500, 0);

  /// Body/Large: 16/24 Regular.
  static final bodyLarge = _s(16, 24, FontWeight.w400, 0);

  /// Body/Medium: 14/20 Regular.
  static final bodyMedium = _s(14, 20, FontWeight.w400, 0.15);

  /// Body/Small: 13/20 Regular.
  static final bodySmall = _s(13, 20, FontWeight.w400, 0.25);

  /// Label/Large: 14/16 Medium.
  static final labelLarge = _s(14, 16, FontWeight.w500, 0.15);

  /// Label/Medium: 13/16 Medium.
  static final labelMedium = _s(13, 16, FontWeight.w500, 0.25);

  /// Label/Small: 12/16 Medium.
  static final labelSmall = _s(12, 16, FontWeight.w500, 0.25);

  /// Overline/Medium: 12/16 Medium, upper case, wide tracking.
  static final overline = _s(12, 16, FontWeight.w500, 1, RiderColors.brand);

  /// Caption/Medium: 12/16 Regular.
  static final caption = _s(12, 16, FontWeight.w400, 0.25, RiderColors.grey);

  /// Caption/Small: 11/16 Regular.
  static final captionSmall = _s(11, 16, FontWeight.w400, 0.25, RiderColors.grey);

  /// The break's clock: 48/56 SemiBold, -1 (Shift 44, 45).
  static final timer = _s(48, 56, FontWeight.w600, -1);

  /// Button/Medium: 16/18 SemiBold.
  static final button = _s(16, 18, FontWeight.w600, 0.25);

  /// Link/Medium: 14/16 Regular.
  static final link = _s(14, 16, FontWeight.w400, 0, RiderColors.brand);
}

/// Corner radii (Figma radius variables).
abstract final class RiderRadius {
  static const s = 8.0;
  static const m = 12.0;

  /// Input fields and code boxes; small cards (Shift 53).
  static const field = 16.0;
  static const card = 20.0;
  static const sheet = 32.0;
  static const pill = 999.0;
}

/// Status bar styles: dark icons on light screens, light icons on green ones
/// (Splash, Welcome). Every full-screen design sets one, so the style of the
/// previous screen never leaks.
const riderStatusBarDark = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);
const riderStatusBarLight = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// Flutter spreads a blur number wider than Figma (sigma 0.577r + 0.5 vs r / 2),
/// so Figma blur B is written here as (B / 2 - 0.5) / 0.577.
/// Standard soft shadow: 0 2 2 rgba(12,12,12,0.1).
const riderShadow = [BoxShadow(color: RiderColors.shadow, offset: Offset(0, 2), blurRadius: 2)];

class AppTheme {
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

/// Paddings, bars and shadows shared by a screen.
abstract final class RiderLayout {
  static const earningsSyncWhiteBar = BoxDecoration(color: RiderColors.white, boxShadow: riderShadow);
  static const earningsSyncWhiteBarPadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s12, AppSizes.s16, AppSizes.s24);
  static const earningsSyncHeaderPadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s12);
  static const profileSegmentShadow = [BoxShadow(color: RiderColors.shadow, offset: Offset(AppSizes.s0, AppSizes.s2), blurRadius: AppSizes.s4_33)];
  static const handoverHeaderGap12 = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s12);
  static const handoverBottomPadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s24, AppSizes.s16, AppSizes.s12);
  static const handoverWhiteBar = BoxDecoration(color: RiderColors.white, boxShadow: riderShadow);
  static const handoverWhiteBarPadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s12, AppSizes.s16, AppSizes.s24);
  static const breakPagePadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s72, AppSizes.s16, AppSizes.s16);
  static const breakActionsPadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12);
  static const chooseSpotCardShadow = [BoxShadow(color: RiderColors.cardShadow, offset: Offset(AppSizes.s0, AppSizes.s2), blurRadius: AppSizes.s2_6)];
  static const chooseSpotIntoStatusBar = AppSizes.s12_0;
  static const chooseSpotFullnessBarHeight = AppSizes.s6_0;
  /// Where the design draws the spot's dot.
  static const goOnlineSpotY = AppSizes.s250_0;
  /// Order 03 keeps the sheet this tall, its buttons where Order 02's are.
  static const orderLateSheetHeight = AppSizes.s388_0;
  /// Order 01's sheet runs 6px off the 800px frame in the design.
  static const orderAssignedBottomGap = AppSizes.s6_0;
  /// The sheet runs 6px off the 800px frame in the design.
  static const skipOrderBottomGap = AppSizes.s6_0;
  static const hubMapDistancePx = AppSizes.s128_0;
  static const hubMapAboveCentrePx = AppSizes.s20_0;
  /// Shared padding for the stock screens' pinned actions: the 56px button
  /// ends 12px above the 16px gesture bar.
  static const stockActionsPadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12);
  /// White bar under Stock 07, 08, 13, 14, running to the screen's edge.
  static const stockWhiteBar = BoxDecoration(color: RiderColors.white, boxShadow: riderShadow);
  static const stockWhiteBarPadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s12, AppSizes.s16, AppSizes.s24);
  static const onlineMapSpotY = AppSizes.s230_0;
  static const onlineMapSpotYUnderBanner = AppSizes.s258_0;
  static const orderGateY = AppSizes.s200_0;
  static const orderGateYUnderNotice = AppSizes.s236_0;
  static const artTileTintShadow = BoxShadow(color: RiderColors.brandTint, offset: Offset(AppSizes.s0, AppSizes.s8), blurRadius: AppSizes.s16_5);
  static const artTileShadow = BoxShadow(color: RiderColors.shadow, offset: Offset(AppSizes.s0, AppSizes.s8), blurRadius: AppSizes.s9_5);
  static const shadowShadow2x2_6 = [BoxShadow(color: RiderColors.shadow, offset: Offset(AppSizes.s0, AppSizes.s2), blurRadius: AppSizes.s2_6)];
  static const brand30Shadow8x16_5 = [BoxShadow(color: RiderColors.brand30, offset: Offset(AppSizes.s0, AppSizes.s8), blurRadius: AppSizes.s16_5)];
  static const shadowShadow4x11_3 = [BoxShadow(color: RiderColors.shadow, offset: Offset(AppSizes.s0, AppSizes.s4), blurRadius: AppSizes.s11_3)];
  static const sheetShadowShadow16x40_7 = [BoxShadow(color: RiderColors.sheetShadow, offset: Offset(AppSizes.s0, AppSizes.s16), blurRadius: AppSizes.s40_7)];
  static const brand20Shadow12x23_4 = [BoxShadow(color: RiderColors.brand20, offset: Offset(AppSizes.s0, AppSizes.s12), blurRadius: AppSizes.s23_4)];
  static const brand30Shadow6x11_3 = [BoxShadow(color: RiderColors.brand30, offset: Offset(AppSizes.s0, AppSizes.s6), blurRadius: AppSizes.s11_3)];
  static const brand40Shadow18x30_3 = [BoxShadow(color: RiderColors.brand40, offset: Offset(AppSizes.s0, AppSizes.s18), blurRadius: AppSizes.s30_3)];
  static const brand30Shadow3x4_33 = [BoxShadow(color: RiderColors.brand30, offset: Offset(AppSizes.s0, AppSizes.s3), blurRadius: AppSizes.s4_33)];
  static const inkFaintShadow2x2_6 = [BoxShadow(color: RiderColors.inkFaint, offset: Offset(AppSizes.s0, AppSizes.s2), blurRadius: AppSizes.s2_6)];
  static const shadowShadow2x3_46 = [BoxShadow(color: RiderColors.shadow, offset: Offset(AppSizes.s0, AppSizes.s2), blurRadius: AppSizes.s3_46)];
  static const sheetTopShadowShadow4x9_5 = [BoxShadow(color: RiderColors.sheetTopShadow, offset: Offset(AppSizes.s0, -AppSizes.s4), blurRadius: AppSizes.s9_5)];
}
