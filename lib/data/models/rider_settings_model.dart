import '../../domain/entities/delivery_order.dart' show SkipReason;
import '../../domain/entities/online_status.dart' show AddTimeOption, BreakOption;
import '../../domain/entities/pre_shift_check.dart';
import '../../domain/entities/problem_report.dart' show ProblemKind;
import '../../domain/entities/rider_settings.dart';

/// `GET /riders/me/settings` as [RiderSettings]. A value the zone has none of
/// keeps what the app had (the last loaded, or the design's at first).
RiderSettings riderSettingsFromJson(Map<String, dynamic> json, {RiderSettings fallback = RiderSettings.defaults}) {
  int? n(String key) => (json[key] as num?)?.toInt();
  List<Map<String, dynamic>> list(String key) => [...(json[key] as List? ?? const []).cast<Map<String, dynamic>>()];
  List<Duration> lengths(String key) => [for (final s in (json[key] as List? ?? const [])) Duration(seconds: (s as num).toInt())];

  final breaks = lengths('break_options_s');
  final addTime = lengths('add_time_options_s');
  final skips = list('skip_reasons');
  final problems = list('problem_types');
  final checks = list('checklist');
  Duration seconds(String key, Duration fallback) => n(key) == null ? fallback : Duration(seconds: n(key)!);
  return RiderSettings(
    stockAskBefore: seconds('stock_request_ask_before_s', fallback.stockAskBefore),
    stockReminderBefore: seconds('stock_request_reminder_before_s', fallback.stockReminderBefore),
    endingSoonBefore: seconds('shift_ending_soon_before_s', fallback.endingSoonBefore),
    breakExtension: seconds('break_extension_s', fallback.breakExtension),
    notAtGateAfter: seconds('not_at_gate_after_s', fallback.notAtGateAfter),
    handoverCodeLength: n('handover_code_length') ?? fallback.handoverCodeLength,
    verificationWithin: seconds('verification_within_s', fallback.verificationWithin),
    cancelPayCap: switch ((json['cancel_pay_cap'] as Map<String, dynamic>?)?['amount_minor']) {
      final num paise => paise ~/ 100,
      _ => fallback.cancelPayCap,
    },
    timerLength: n('timer_length_s') == null ? fallback.timerLength : Duration(seconds: n('timer_length_s')!),
    arriveMeters: n('arrive_m')?.toDouble() ?? fallback.arriveMeters,
    almostThereMeters: n('almost_there_m')?.toDouble() ?? fallback.almostThereMeters,
    awayFromSpotMeters: n('away_from_spot_m')?.toDouble() ?? fallback.awayFromSpotMeters,
    lowStockQty: n('low_stock_qty') ?? fallback.lowStockQty,
    scooterCapacity: n('scooter_capacity_qty') ?? fallback.scooterCapacity,
    minPhoneBattery: n('min_phone_battery_pct') ?? fallback.minPhoneBattery,
    minScooterBattery: n('min_scooter_battery_pct') ?? fallback.minScooterBattery,
    lowScooterBattery: n('low_scooter_battery_pct') ?? fallback.lowScooterBattery,
    rideSpeedKmh: n('ride_speed_kmh')?.toDouble() ?? fallback.rideSpeedKmh,
    breakOptions: breaks.isEmpty ? fallback.breakOptions : [for (final d in breaks) BreakOption(d)],
    addTimeOptions: addTime.isEmpty ? fallback.addTimeOptions : [for (final d in addTime) AddTimeOption(d)],
    skipReasons: skips.isEmpty
        ? fallback.skipReasons
        : [for (final s in skips) SkipReason(s['code'] as String, s['label'] as String? ?? '')],
    problemKinds: problems.isEmpty
        ? fallback.problemKinds
        : [
            for (final p in problems)
              ProblemKind(p['code'] as String, p['label'] as String? ?? '', p['hint'] as String? ?? ''),
          ],
    checklist: checks.isEmpty
        ? fallback.checklist
        : [
            for (final c in checks)
              PreShiftCheck(c['code'] as String, c['label'] as String? ?? '', CheckKind.of(c['check'] as String?), c['hint'] as String?),
          ],
  );
}
