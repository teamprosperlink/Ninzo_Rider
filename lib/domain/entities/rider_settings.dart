import 'delivery_order.dart' show SkipReason;
import 'online_status.dart' show AddTimeOption, BreakOption;
import 'pre_shift_check.dart';
import 'problem_report.dart' show ProblemKind;

/// What the rider app works by: the zone's settings and every choice the app
/// offers. With the rider API it is `GET /riders/me/settings`, set as
/// [current] once loaded, so the app has none of its own. Demo and tests use
/// [defaults], the values the design was drawn with.
class RiderSettings {
  const RiderSettings({
    required this.timerLength,
    required this.arriveMeters,
    required this.almostThereMeters,
    required this.awayFromSpotMeters,
    required this.lowStockQty,
    required this.scooterCapacity,
    required this.minPhoneBattery,
    required this.minScooterBattery,
    required this.lowScooterBattery,
    required this.rideSpeedKmh,
    required this.breakOptions,
    required this.addTimeOptions,
    required this.skipReasons,
    required this.problemKinds,
    required this.checklist,
    this.stockAskBefore = const Duration(hours: 1),
    this.stockReminderBefore = const Duration(minutes: 30),
    this.endingSoonBefore = const Duration(minutes: 15),
    this.breakExtension = const Duration(minutes: 15),
    this.notAtGateAfter = const Duration(seconds: 15),
    this.handoverCodeLength = 4,
  });

  /// When, before the planned start, the stock request is asked, and when an
  /// unanswered one is reminded.
  final Duration stockAskBefore;
  final Duration stockReminderBefore;

  /// When, before the planned end, "Shift ending soon" shows.
  final Duration endingSoonBefore;

  /// What "+15 min" adds to a break.
  final Duration breakExtension;

  /// The handover's empty code step offers "Customer not at the gate?" after this.
  final Duration notAtGateAfter;

  /// Digits in the customer's handover code.
  final int handoverCodeLength;

  /// The order's visible timer.
  final Duration timerLength;

  /// How close to the hub, the spot or the gate counts as there.
  final double arriveMeters;
  final double almostThereMeters;
  final double awayFromSpotMeters;

  /// Fewer portions of an item than this suggests a refill.
  final int lowStockQty;

  /// Most portions a scooter holds.
  final int scooterCapacity;
  final int minPhoneBattery;
  final int minScooterBattery;
  final int lowScooterBattery;

  /// For ride times, until real road times.
  final double rideSpeedKmh;
  final List<BreakOption> breakOptions;
  final List<AddTimeOption> addTimeOptions;
  final List<SkipReason> skipReasons;
  final List<ProblemKind> problemKinds;
  final List<PreShiftCheck> checklist;

  static const defaults = RiderSettings(
    timerLength: Duration(seconds: 90),
    arriveMeters: 100,
    almostThereMeters: 300,
    awayFromSpotMeters: 150,
    lowStockQty: 5,
    scooterCapacity: 8,
    minPhoneBattery: 50,
    minScooterBattery: 40,
    lowScooterBattery: 20,
    rideSpeedKmh: 15,
    breakOptions: [BreakOption.min15, BreakOption.min30, BreakOption.min45, BreakOption.hr1],
    addTimeOptions: [
      AddTimeOption.min15,
      AddTimeOption.min30,
      AddTimeOption.min45,
      AddTimeOption.hr1,
      AddTimeOption.hrs2,
      AddTimeOption.hrs3,
      AddTimeOption.hrs4,
    ],
    skipReasons: [SkipReason.scooterProblem, SkipReason.itemMissing, SkipReason.notSafe, SkipReason.somethingElse],
    problemKinds: [
      ProblemKind.breakdown,
      ProblemKind.accident,
      ProblemKind.gateClosed,
      ProblemKind.customerAbsent,
      ProblemKind.unsafeRoute,
    ],
    checklist: [
      PreShiftCheck.helmet,
      PreShiftCheck.phoneCharged,
      PreShiftCheck.scooterBattery,
      PreShiftCheck.location,
      PreShiftCheck.insulatedBox,
      PreShiftCheck.scooterClean,
    ],
  );

  /// What the app works by now.
  static RiderSettings current = defaults;
}
