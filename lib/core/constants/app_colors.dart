import 'package:flutter/material.dart';

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

  /// Warning (amber) used by alert states.
  static const warning = Color(0xFFF59E0B);

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

  /// The green pill and avatar behind the end-shift and log-out dialogs.
  static const headerUnderDialog = Color(0xFFDBEDDB);

  /// The green pill on Order 01.
  static const orderAssignedPill = Color(0xFFDBF0DB);

  /// The green pill on Handover 01 and Refill 01.
  static const greenPillOnScreen = Color(0xFFD8EDD8);

  /// The amber status pill on a map sheet.
  static const warningPill = Color(0xFFFDF1DD);
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

  // One-off colours from the Figma frames.
  static const sheetScrim = Color(0x380C0C0C);
  static const sheetShadow = Color(0x330C0C0C);
  static const verifiedGradientStart = Color(0xFFE0F7E0);
  static const verifiedGradientEnd = Color(0xFFC2EDC7);
  static const brand20 = Color(0x33009600);
  static const brand12 = Color(0x1F009600);
  static const cardShadow = Color(0x1F000000);
  static const documentTint = Color(0xFFE8F6E8);
  static const errorHaloInner = Color(0xFFF9DBDB);
  static const errorHaloCore = Color(0xFFFDE8E8);
  static const warningHaloInner = Color(0xFFFAEACD);
  static const brandHaloInner = Color(0xFFD3ECD3);
  static const heroGradientStart = Color(0xFF33D138);
  static const heroGradientEnd = Color(0xFF00800D);
  static const brand40 = Color(0x66009600);
  static const tileGradientStart = Color(0xFFEDFCED);
  static const tileGradientEnd = Color(0xFFCCF0D1);
  static const brand14 = Color(0x24009600);
  static const badgeGradientStart = Color(0xFF38CC3D);
  static const badgeGradientEnd = Color(0xFF00800F);
  static const sheetTopShadow = Color(0x0F000000);
  static const black = Color(0xFF000000);
  static const warningBadge = Color(0xFFFBEACB);
  static const transparent = Color(0x00000000);
}
