import '../../core/constants/app_strings.dart';
import 'rider_settings.dart';

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
  scooterBattery;

  /// The rider API's `check` for an item.
  static CheckKind of(String? check) => switch (check) {
    'phone_battery' => phoneBattery,
    'location' => location,
    'scooter_battery' => scooterBattery,
    _ => manual,
  };
}

/// One item of the "Before you start" checklist (Shift 10–12). The items are
/// the rider API's (`GET /riders/me/settings`); [name] is the code sent with
/// the shift's start. Go to hub unlocks when every item is ticked.
class PreShiftCheck {
  const PreShiftCheck(this.name, this.title, this.kind, [this.hint]);

  final String name;
  final String title;
  final CheckKind kind;

  /// The line under it; the battery items say their level instead.
  final String? hint;

  static const helmet = PreShiftCheck('helmet', AppStrings.helmetOn, CheckKind.manual, AppStrings.wearYourHelmetAtAllTimes);
  static const phoneCharged = PreShiftCheck('phoneCharged', AppStrings.phoneCharged, CheckKind.phoneBattery);
  static const scooterBattery = PreShiftCheck('scooterBattery', AppStrings.scooterBatteryOk, CheckKind.scooterBattery);
  static const location = PreShiftCheck('location', AppStrings.locationIsOn, CheckKind.location, AppStrings.neededToMatchYouWithNearby);
  static const insulatedBox = PreShiftCheck(
    'insulatedBox',
    AppStrings.insulatedBoxReady,
    CheckKind.manual,
    AppStrings.cleanNoLeaksLidClosesFirmly,
  );
  static const scooterClean = PreShiftCheck('scooterClean', AppStrings.scooterIsClean, CheckKind.manual, AppStrings.boxAndSeatWiped);

  static List<PreShiftCheck> get values => RiderSettings.current.checklist;

  /// Phone battery needed to start: the zone's `min_phone_battery_pct`.
  static int get minPhoneBattery => RiderSettings.current.minPhoneBattery;

  @override
  bool operator ==(Object other) => other is PreShiftCheck && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Why a device-backed check can't be ticked.
enum CheckProblem { phoneBatteryLow, locationOff, scooterBatteryLow }
