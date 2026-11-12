/// Counts and unit conversions the screens use.
abstract final class AppLimits {
  static const phoneDigits = 10;

  /// Send feedback's box: the API takes up to 2000 characters.
  static const feedbackMaxChars = 2000;
  static const feedbackMinLines = 3;
  static const feedbackMaxLines = 6;
  static const millisPerSecond = 1000;
  static const metersPerKm = 1000;
  static const secondsPerMinute = 60;
  static const minutesPerHour = 60;
  static const oneLine = 1;
  static const skeletonCards = 3;
  static const threeStats = 3;
  static const registerSteps = 3;
  static const registerDetailsStep = 1;
  static const registerDocumentsStep = 2;
  static const demoLowStockLeft = 5;
  static const orderHighlightRow = 2;
  static const summaryHighlightRow = 3;
  static const flex1 = 1;
  static const flex141 = 141;
  static const flex145 = 145;
  static const flex1565 = 1565;
  static const flex1595 = 1595;
}

/// Map framing numbers.
abstract final class AppMapConfig {
  static const metersPerPxAtZoom0 = 156543.03;
  static const metersPerDegreeLatitude = 111320.0;
  static const waitingZoom = 16.0;
  static const gateZoom = 16.0;
  static const hubZoom = 15.0;

  /// How far the native map runs past the bottom edge of its widget.
  static const belowEdge = 48.0;

  /// How far from the gate the design draws the rider: (meters, pixels).
  static const gateFraming = [(100.0, 38.0), (300.0, 67.0), (600.0, 128.0)];
}

/// Every see-through amount the screens use.
abstract final class AppOpacity {
  /// Figma's #23 alpha on the grey pill.
  static const greyPill = 0x23 / 255;

  static const o0_06 = 0.06;
  static const o0_07 = 0.07;
  static const o0_09 = 0.09;
  static const o0_1 = 0.1;
  static const o0_105 = 0.105;
  static const o0_12 = 0.12;
  static const o0_123 = 0.123;
  static const o0_14 = 0.14;
  static const o0_15 = 0.15;
  static const o0_16 = 0.16;
  static const o0_35 = 0.35;
  static const o0_38 = 0.38;
  static const o0_5 = 0.5;
  static const o0_6 = 0.6;
  static const o0_7 = 0.7;
  static const o0_75 = 0.75;
  static const o0_853 = 0.853;
  static const o1 = 1.0;
}
