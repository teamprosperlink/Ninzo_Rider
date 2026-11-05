import '../../../../core/error/app_exception.dart';
import '../../../shift/domain/entities/shift.dart';
import '../entities/online_status.dart';
import '../repositories/online_repository.dart';
import 'spot_usecases.dart';

/// Watches the online rider's backend values.
class WatchOnlineStatus {
  const WatchOnlineStatus(this._repository);

  final OnlineRepository _repository;

  Stream<OnlineStatus> call(String uid, String shiftId) => _repository.watch(uid, shiftId);
}

/// The shift's end, with any time added.
DateTime shiftEndOf(Shift shift, OnlineStatus status) => status.shiftEnd ?? shift.end;

ScooterStock scooterStockOf(Shift shift, OnlineStatus status) {
  final left = shift.stock.portions + status.stockAdded - status.sold;
  return ScooterStock(kinds: shift.stock.items, portionsLeft: left < 0 ? 0 : left);
}

/// The rider sees 1 order now plus up to 4 waiting; anything beyond that
/// stays hidden from them.
const maxVisibleOrders = 5;

List<AssignedOrder> visibleOrders(OnlineStatus status) => status.queue.take(maxVisibleOrders).toList();

/// Which sheet the main map shows. An order beats everything, then being away
/// (no orders come), then the moment of confirming, then a quiet spell.
OnlineMode onlineModeOf(OnlineStatus status, {double? metersFromSpot, bool justConfirmed = false}) {
  if (status.queue.isNotEmpty) return OnlineMode.orderAssigned;
  if (metersFromSpot != null && SpotRules.isAway(metersFromSpot)) return OnlineMode.away;
  if (justConfirmed) return OnlineMode.spotConfirmed;
  return status.quiet ? OnlineMode.quiet : OnlineMode.waiting;
}

/// Picks the one banner over the main map when several apply, most urgent
/// first:
///
/// 1. no signal: nothing else can be trusted until it's back;
/// 2. "Time added", which the rider just asked for and lasts a few seconds;
/// 3. away from the spot: no orders reach them at all;
/// 4. shift ending: a decision with a deadline;
/// 5. a nudge to another spot, or that it's been covered;
/// 6. scooter battery low;
/// 7. low stock: orders still come until it runs out.
///
/// None while an order is assigned: the rider has that to do first.
class SelectOnlineAlert {
  const SelectOnlineAlert();

  /// The shift-ending banner shows this long before the end.
  static const endingWindow = Duration(minutes: 15);

  OnlineAlert? call({
    required Shift shift,
    required OnlineStatus status,
    required DateTime now,
    double? metersFromSpot,
    DateTime? timeAddedEnd,
    DateTime? endingDismissedFor,
    bool offline = false,
    int waitingToSync = 0,
  }) {
    if (status.queue.isNotEmpty) return null;
    if (offline) return ConnectionLostAlert(waitingToSync);
    if (timeAddedEnd != null) return TimeAddedAlert(timeAddedEnd);
    if (metersFromSpot != null && SpotRules.isAway(metersFromSpot)) return AwayFromSpotAlert(metersFromSpot);
    final end = shiftEndOf(shift, status);
    final left = end.difference(now);
    if (end != endingDismissedFor && !left.isNegative && left <= endingWindow) {
      return ShiftEndingAlert((left.inSeconds / 60).ceil());
    }
    final nudge = status.nudge;
    if (nudge != null) {
      switch (nudge.stage) {
        case NudgeStage.offered:
          return RelocationNudgeAlert(nudge);
        case NudgeStage.covered:
          return NudgeCoveredAlert(nudge);
        case NudgeStage.accepted:
          break;
      }
    }
    final battery = status.batteryPercent ?? shift.scooter.batteryPercent;
    if (battery != null && battery <= Scooter.lowBatteryPercent) return BatteryLowAlert(battery);
    final stock = scooterStockOf(shift, status);
    if (stock.isLow) return LowStockAlert(stock.portionsLeft);
    return null;
  }
}

/// Keep riding (Shift 33 → 34 → 35): moves the shift's end. Returns the new
/// end. No action means the shift ends on time.
class AddShiftTime {
  const AddShiftTime(this._repository);

  final OnlineRepository _repository;

  Future<DateTime> call(String uid, Shift shift, OnlineStatus status, AddTimeOption option) async {
    if (shift.phase != ShiftPhase.online) throw const AppException();
    final end = shiftEndOf(shift, status).add(option.duration);
    await _repository.setShiftEnd(uid, shift.id, end);
    return end;
  }
}

/// "Start order" (Shift 28): the first in the queue.
class StartOrder {
  const StartOrder(this._repository);

  final OnlineRepository _repository;

  Future<AssignedOrder?> call(String uid, Shift shift, OnlineStatus status) async {
    if (status.queue.isEmpty) return null;
    final order = status.queue.first;
    await _repository.startOrder(uid, shift.id, order);
    return order;
  }
}

/// "Back to your spot" (Order 05, Navigate 04–06): the order is done with and
/// the main map returns; the next in the queue shows on Shift 28.
class FinishOrder {
  const FinishOrder(this._repository);

  final OnlineRepository _repository;

  Future<void> call(String uid, Shift shift, String orderId) => _repository.finishOrder(uid, shift.id, orderId);
}
