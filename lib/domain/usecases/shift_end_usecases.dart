import '../../core/errors/app_exception.dart';
import '../entities/online_status.dart';
import '../repositories/online_repository.dart';
import 'online_usecases.dart';
import '../entities/shift.dart';
import '../repositories/shift_repository.dart';
import '../repositories/stock_repository.dart';
import '../entities/shift_end.dart';
import '../repositories/shift_end_repositories.dart';

/// Opens the shift on this phone before "Start riding" goes on (Shift 05 → 06,
/// or 54, 55). It needs signal; another phone's shift is taken over only when
/// the rider says so ("Continue on this phone").
class OpenShift {
  const OpenShift(this._signal, this._sessions);

  final SignalRepository _signal;
  final ShiftSessionRepository _sessions;

  Future<OpenShiftResult> call(String uid, String shiftId, {bool takeOver = false}) async {
    if (!await _signal.isOnline()) return OpenShiftResult.noInternet;
    if (!takeOver && await _sessions.openElsewhere(uid, shiftId)) return OpenShiftResult.alreadyOpen;
    await _sessions.claim(uid, shiftId);
    return OpenShiftResult.opened;
  }
}

/// What stops the rider on the main map, most urgent first (Shift 41, 42).
class CheckDeviceHealth {
  const CheckDeviceHealth(this._device);

  final DeviceHealthRepository _device;

  Future<ShiftIssue?> call() async {
    if (!await _device.locationOn()) return ShiftIssue.locationOff;
    if (!await _device.phoneTimeAutomatic()) return ShiftIssue.phoneTimeWrong;
    return null;
  }
}

/// "End shift" (Shift 48 → 49 → 50). An order on the scooter comes first
/// (Shift 47). Ending from a break ends the break too.
class EndShift {
  const EndShift(this._shifts, this._online, this._sessions);

  final ShiftRepository _shifts;
  final OnlineRepository _online;
  final ShiftSessionRepository _sessions;

  Future<EndShiftResult> call(String uid, Shift shift, OnlineStatus status) async {
    if (status.queue.isNotEmpty || status.activeOrderId != null) return EndShiftResult.orderInProgress;
    if (status.breakState != null) await _online.setBreak(uid, shift.id, null);
    await _sessions.markEnded(uid, shift.id);
    try {
      await _shifts.setPhase(uid, shift.id, ShiftPhase.ended);
    } on AppException catch (e) {
      // The backend knows of an order the phone doesn't show yet.
      if (e.reason == AppErrorReasons.orderInProgress) return EndShiftResult.orderInProgress;
      rethrow;
    }
    return EndShiftResult.ended;
  }
}

/// The day so far (Shift 46, 48, 50).
class ShiftTotals {
  const ShiftTotals({
    required this.orders,
    required this.left,
    required this.sold,
    required this.onlineTime,
    required this.earned,
    this.averageDeliverySeconds,
  });

  factory ShiftTotals.of(Shift shift, OnlineStatus status, DateTime now) {
    final since = status.onlineAt;
    return ShiftTotals(
      orders: status.orders,
      left: scooterStockOf(shift, status).portionsLeft,
      sold: status.sold,
      onlineTime: since == null ? Duration.zero : now.difference(since),
      earned: status.earned,
      averageDeliverySeconds: status.averageDeliverySeconds,
    );
  }

  final int orders;

  /// Portions still on the scooter.
  final int left;
  final int sold;
  final Duration onlineTime;
  final double earned;
  final int? averageDeliverySeconds;
}

/// "You chose 8 hours": how long the shift was set to run.
Duration chosenShiftLength(Shift shift, OnlineStatus status) =>
    status.chosenLength ?? shiftEndOf(shift, status).difference(shift.start);

/// Earnings 01. Before the backend splits the day's pay, it's all order pay.
EarningsBreakdown earningsOf(OnlineStatus status) => status.earnings ?? EarningsBreakdown(orderPay: status.earned);

/// What is still waiting to go up (Shift 40, Earnings).
class LoadSyncStatus {
  const LoadSyncStatus(this._repository);

  final SyncStatusRepository _repository;

  Future<SyncSnapshot> call(String uid) => _repository.load(uid);
}

/// Sends what it can now.
class RetrySync {
  const RetrySync(this._repository);

  final SyncStatusRepository _repository;

  Future<void> call(String uid) => _repository.retry(uid);
}

/// Location services on and permission granted.
class IsLocationOn {
  const IsLocationOn(this._health);

  final DeviceHealthRepository _health;

  Future<bool> call() => _health.locationOn();
}

/// The phone sets its date and time automatically.
class IsPhoneTimeAutomatic {
  const IsPhoneTimeAutomatic(this._health);

  final DeviceHealthRepository _health;

  Future<bool> call() => _health.phoneTimeAutomatic();
}

class OpenLocationSettings {
  const OpenLocationSettings(this._health);

  final DeviceHealthRepository _health;

  Future<void> call() => _health.openLocationSettings();
}

class OpenDateSettings {
  const OpenDateSettings(this._health);

  final DeviceHealthRepository _health;

  Future<void> call() => _health.openDateSettings();
}
