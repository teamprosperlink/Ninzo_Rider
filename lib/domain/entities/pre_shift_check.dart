import '../../core/constants/app_strings.dart';
/// How a pre-shift check is confirmed.
enum CheckKind {
  /// The rider ticks it.
  manual,

  /// The phone checks it when ticked: battery level.
  phoneBattery,

  /// The phone checks it when ticked: location services and permission.
  location,

  /// The rider ticks it after reading the scooter's charge; blocked when the
  /// telemetry says it's too low.
  scooterBattery,
}

/// The "Before you start" checklist (Shift 10–12). Go to hub unlocks when
/// every item is ticked.
enum PreShiftCheck {
  helmet(AppStrings.helmetOn, CheckKind.manual),
  phoneCharged(AppStrings.phoneCharged, CheckKind.phoneBattery),
  scooterBattery(AppStrings.scooterBatteryOk, CheckKind.scooterBattery),
  location(AppStrings.locationIsOn, CheckKind.location),
  insulatedBox(AppStrings.insulatedBoxReady, CheckKind.manual),
  scooterClean(AppStrings.scooterIsClean, CheckKind.manual);

  const PreShiftCheck(this.title, this.kind);

  final String title;
  final CheckKind kind;

  /// Phone battery needed to start.
  static const minPhoneBattery = 50;
}

/// Why a device-backed check can't be ticked.
enum CheckProblem { phoneBatteryLow, locationOff, scooterBatteryLow }
