import '../entities/shift.dart';
import '../entities/shift_push.dart';

/// When the stock-request pushes go out for a shift.
abstract interface class PushTimes {
  DateTime askAt(Shift shift);
  DateTime reminderAt(Shift shift);
}

/// 1 hour and 30 minutes before the shift starts.
class ShiftPushTimes implements PushTimes {
  const ShiftPushTimes();

  static const ask = Duration(hours: 1);
  static const reminder = Duration(minutes: 30);

  @override
  DateTime askAt(Shift shift) => shift.start.subtract(ask);

  @override
  DateTime reminderAt(Shift shift) => shift.start.subtract(reminder);
}

/// What to do with the pushes after a change to the shift.
class PushPlan {
  const PushPlan({this.schedule = const {}, this.cancel = const {}, this.showNow = const {}, this.detail = const PushDetail()});

  final Map<ShiftPush, DateTime> schedule;
  final Set<ShiftPush> cancel;
  final Set<ShiftPush> showNow;

  /// What [showNow]'s pushes say beyond the shift.
  final PushDetail detail;
}

/// The morning stock request rules: ask 1 h before; with no reply, remind
/// at 30 min; a reply cancels both. "Stock ready" when the hub finishes
/// packing.
class PlanShiftPushes {
  const PlanShiftPushes(this._times);

  final PushTimes _times;

  /// A push due less than this long ago still shows (the app was closed).
  static const grace = Duration(minutes: 5);

  PushPlan call(Shift shift, DateTime now, {Shift? previous}) {
    final waiting =
        shift.phase == ShiftPhase.notStarted &&
        (shift.stockRequest == StockRequestStatus.notRequested ||
            shift.stockRequest == StockRequestStatus.awaitingReply);
    final becameReady =
        previous != null &&
        previous.id == shift.id &&
        previous.stockRequest != StockRequestStatus.ready &&
        shift.stockRequest == StockRequestStatus.ready;
    if (!waiting) {
      return PushPlan(
        cancel: {ShiftPush.prepareStock, ShiftPush.reminder},
        showNow: {if (becameReady) ShiftPush.stockReady},
      );
    }
    final due = {ShiftPush.prepareStock: _times.askAt(shift), ShiftPush.reminder: _times.reminderAt(shift)};
    return PushPlan(
      schedule: {
        for (final MapEntry(key: push, value: at) in due.entries)
          if (at.isAfter(now.subtract(grace))) push: at,
      },
    );
  }
}
