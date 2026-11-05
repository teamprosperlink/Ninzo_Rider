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
  helmet('Helmet on', CheckKind.manual),
  phoneCharged('Phone charged', CheckKind.phoneBattery),
  scooterBattery('Scooter battery OK', CheckKind.scooterBattery),
  location('Location is on', CheckKind.location),
  insulatedBox('Insulated box ready', CheckKind.manual),
  scooterClean('Scooter is clean', CheckKind.manual);

  const PreShiftCheck(this.title, this.kind);

  final String title;
  final CheckKind kind;

  /// Phone battery needed to start.
  static const minPhoneBattery = 50;
}

/// Why a device-backed check can't be ticked.
enum CheckProblem { phoneBatteryLow, locationOff, scooterBatteryLow }
