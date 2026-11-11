/// Every length of time the screens use.
abstract final class AppDurations {
  static const milliseconds100 = Duration(milliseconds: 100);
  static const milliseconds900 = Duration(milliseconds: 900);
  static const seconds1 = Duration(seconds: 1);
  static const seconds15 = Duration(seconds: 15);
  static const seconds20 = Duration(seconds: 20);
  static const seconds3 = Duration(seconds: 3);
  static const seconds30 = Duration(seconds: 30);
  static const seconds5 = Duration(seconds: 5);
  static const seconds6 = Duration(seconds: 6);

  /// Seconds before a new code can be asked for.
  /// How long the splash stays up at least.
  static const splash = seconds3;
  static const resendCooldown = seconds30;
  /// How long Shift 25 "Online · at spot" stays.
  static const spotConfirmedHold = seconds5;
  static const chooseSpotRetryAfter = seconds5;
  /// "Not yet, still on the way" while within reach: ask again after this.
  static const goOnlineAskAgainAfter = seconds20;
  /// So "Checking your location…" can be read.
  static const goOnlineCheckAtLeast = milliseconds900;
  /// How long Shift 35 "Time added" stays.
  static const timeAddedHold = seconds6;
  static const shiftEndCheckEvery = seconds15;
  /// So "Ending shift…" can be read.
  static const endingShiftAtLeast = milliseconds900;
  static const locationCheckEvery = seconds3;
  static const stockToast = seconds3;

  /// How long typing has to pause before a place search goes out.
  static const placeSearchPause = Duration(milliseconds: 300);
}
