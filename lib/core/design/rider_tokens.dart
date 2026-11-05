import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens from the Figma file "Ninzo Project" (Rider App). Names follow
/// the Figma variables so a screen's design context maps one to one.
abstract final class RiderColors {
  /// Fill/Brand, Text/Brand, Icon/Brand, Button/Fill/Primary.
  static const brand = Color(0xFF009600);

  /// Button/Fill/Primary/Disabled.
  static const brandDisabled = Color(0xFF54B954);

  /// Brand at 10%: pills, icon tiles, avatars.
  static const brandTint = Color(0x1A009600);

  /// Colors/Brand/Opacity/300.
  static const brand30 = Color(0x4D009600);

  /// Background/Screen.
  static const screen = Color(0xFFFBFBFB);

  /// Background/Overlay: map base, input fill.
  static const overlay = Color(0xFFF5F5F5);

  static const white = Color(0xFFFFFFFF);

  /// Text/White & Black, Fill/White & Black.
  static const ink = Color(0xFF0C0C0C);

  /// Text/Grey, Fill/Gray, Icon/Grey.
  static const grey = Color(0xFF767676);

  /// Divider/Line/Grey/Opacity/300.
  static const divider = Color(0x4D767676);

  /// Colors/Black/Opacity/100: card and sheet shadows.
  static const shadow = Color(0x1A0C0C0C);

  /// Semantic/Error.
  static const error = Color(0xFFEF4444);
  static const errorTint = Color(0x1AEF4444);

  /// Warning (amber) used by alert states.
  static const warning = Color(0xFFF59E0B);
  static const warningTint = Color(0x1AF59E0B);

  /// Text on warning states ("Your account is on hold").
  static const warningText = Color(0xFFB45309);

  /// Empty input fields: ink at 5%.
  static const inkFaint = Color(0x0D0C0C0C);

  /// Empty code boxes: ink at 4%.
  static const codeSlot = Color(0x0B0C0C0C);

  /// Home avatar: brand at 12.5%.
  static const avatarTint = Color(0x20009600);

  /// Tip box fill and its icon tile (Register 06).
  static const tipFill = Color(0xFFF9EFDD);
  static const tipTile = Color(0xFFF8E2BC);

  /// Photo preview over its shadow (Register 06). Opaque, because Flutter
  /// paints a box shadow under a translucent fill and Figma doesn't.
  static const photoPreview = Color(0xFFE2E2E2);

  /// Hairline card borders: ink at 6%.
  static const hairline = Color(0x0F0C0C0C);

  /// Border of the 16-radius result and status panels: ink at 8%.
  static const panelBorder = Color(0x150C0C0C);

  /// Unchecked step ring (Shift 53).
  static const stepRing = Color(0xFFCDCDCD);

  /// Inactive step bars (register): ink at 8%.
  static const track = Color(0x140C0C0C);

  /// Camera viewfinder placeholder (Register 05).
  static const viewfinder = Color(0xFF2A2A2A);

  /// Photo preview placeholder (Register 06): ink at 10%.
  static const photoPlaceholder = Color(0x1A0C0C0C);

  /// Warning notice fill (Stock 04, 10, 11, 16).
  static const warningFill = Color(0xFFFAEEDA);

  /// Alert banner over the map: fill, border and chip (Shift 29–32, 35).
  static const warningBanner = Color(0xFFFDF3E1);
  static const warningBannerBorder = Color(0xFFFBD596);
  static const warningChip = Color(0xFFFBE8C7);

  /// Error banner fill (Stock 07, 08).
  static const errorFill = Color(0xFFF9E8E8);

  /// Text/Semantic/Error/Pressed: text on the error banner.
  static const errorPressed = Color(0xFFB91C1C);

  /// Progress bar track (Stock 01–03).
  static const progressTrack = Color(0xFFE9E9E9);

  /// Quantity stepper track (Stock 05).
  static const stepperTrack = Color(0xFFECECEC);

  /// Tick halo: outer and inner circle (Stock 06, 13).
  static const haloOuter = Color(0xFFE1F0E1);
  static const haloInner = Color(0xFFCAE7CA);

  /// Tick halo on the delivered screens (Handover 06, 11).
  static const deliveredHaloOuter = Color(0xFFDCEEDC);
  static const deliveredHaloInner = Color(0xFFC6E5C6);

  /// Scrim behind a modal sheet (Order 04): ink at 45%.
  static const scrim = Color(0x730C0C0C);

  /// A chosen option card (Problem 02).
  static const optionSelected = Color(0xFFE4F2E4);

  /// Refill 02's banner.
  static const refillBanner = Color(0xFFD8EDD8);

  /// Item tile stand-in and its dot (Refill 03).
  static const itemTile = Color(0xFFEEEEEE);
  static const itemTileDot = Color(0xFFB2D8B2);

  /// Spot tile and the outlined button on the nudge card (Shift 36, 39).
  static const nudgeTile = Color(0xFFE5F4E5);
  static const nudgeOutline = Color(0xFFDBDBDB);

  /// The break's progress track (Shift 44, 45).
  static const breakTrack = Color(0xFFE8E8E8);

  /// Segmented control track (Profile 02, 06, 09).
  static const segmentTrack = Color(0xFFEDEDED);

  /// Log out tile (Profile 01), over white.
  static const errorTile = Color(0xFFFDECEC);

  /// Profile 04's flat spot map and the pulse round its dot.
  static const spotMapFill = Color(0xFFE7F3E7);
  static const spotMapPulse = Color(0xFFB9E1B9);

  /// Choose a spot (Shift 13–17): screen, card border, skeleton bars and the
  /// fullness track.
  static const spotScreen = Color(0xFFFAFAFA);
  static const spotCardBorder = Color(0xFFEBEBEB);
  static const spotSkeleton = Color(0xFFECECEC);
  static const spotTrack = Color(0xFFE7E7E7);

  /// Background behind the on-screen numeric keypad.
  static const keypad = Color(0xFFE3E3E3);
}

/// Text styles from the Figma type scale. All Inter.
abstract final class RiderText {
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

/// Spacing scale (Figma "Size Values").
abstract final class RiderSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 28.0;
  static const xxxxl = 40.0;
  static const huge = 48.0;
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
