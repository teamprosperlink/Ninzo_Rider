import '../../core/constants/app_mode.dart';
import 'package:latlong2/latlong.dart';

import '../../core/errors/app_exception.dart';
import '../repositories/stock_repository.dart';
import '../entities/pre_shift_check.dart';
import '../entities/shift.dart';
import '../repositories/device_status_repository.dart';
import '../repositories/shift_repository.dart';
import '../entities/go_online_result.dart';
import '../entities/rider_settings.dart';

export '../entities/go_online_result.dart';

/// Watches today's shift.
class WatchTodayShift {
  const WatchTodayShift(this._repository);

  final ShiftRepository _repository;

  Stream<Shift?> call(String uid) => _repository.watchToday(uid);
}

/// "Start riding" (Shift 04, 05 → 06 → 10): opens the pre-shift checklist.
/// The hub must know the rider is coming (it packs only after a yes); the
/// rider can leave once the stock is packed or the shift has begun.
class StartShift {
  const StartShift(this._repository, this._clock);

  final ShiftRepository _repository;
  final DateTime Function() _clock;

  Future<void> call(String uid, Shift shift) async {
    if (!shift.stockRequest.confirmed) {
      throw const AppException();
    }
    if (shift.stockRequest != StockRequestStatus.ready && !shift.hasStarted(_clock())) {
      throw const AppException();
    }
    // The rider API allows another shift after one has ended the same day.
    final again = kRiderApi && shift.phase == ShiftPhase.ended;
    if (shift.phase != ShiftPhase.notStarted && shift.phase != ShiftPhase.checklist && !again) return;
    await _repository.setPhase(uid, shift.id, ShiftPhase.checklist);
  }
}

/// Checks a device-backed pre-shift item when the rider ticks it. Null
/// means it can be ticked.
class CheckPreShiftItem {
  const CheckPreShiftItem(this._device);

  final DeviceStatusRepository _device;

  Future<CheckProblem?> call(PreShiftCheck check, Shift shift) async => switch (check.kind) {
    CheckKind.manual => null,
    CheckKind.phoneBattery =>
      await _device.phoneBattery() >= PreShiftCheck.minPhoneBattery ? null : CheckProblem.phoneBatteryLow,
    CheckKind.location => await _device.locationOn() ? null : CheckProblem.locationOff,
    // Unknown (no telemetry yet): the rider checks the scooter, and the tick goes with the shift start.
    CheckKind.scooterBattery => shift.scooter.batteryTooLow ? CheckProblem.scooterBatteryLow : null,
  };
}

/// "Go to hub" (Shift 12 → 52): every check ticked.
class FinishChecklist {
  const FinishChecklist(this._repository);

  final ShiftRepository _repository;

  Future<void> call(String uid, Shift shift, Set<PreShiftCheck> ticked) async {
    if (!ticked.containsAll(PreShiftCheck.values)) {
      throw const AppException();
    }
    await _repository.recordChecklist(uid, shift.id, ticked);
    await _repository.setPhase(uid, shift.id, ShiftPhase.headingToHub);
  }
}

/// The rider reached the hub (Shift 52 → 53 while packing, or Refill 03).
class ArriveAtHub {
  const ArriveAtHub(this._repository);

  final ShiftRepository _repository;

  /// Within this distance of the hub counts as arrived.
  static double get radiusMeters => RiderSettings.current.arriveMeters;

  bool isAtHub(Shift shift, LatLng position) =>
      const Distance().as(LengthUnit.Meter, position, shift.hub.point) <= radiusMeters;

  Future<void> call(String uid, Shift shift) async {
    if (shift.phase != ShiftPhase.headingToHub) return;
    await _repository.setPhase(uid, shift.id, ShiftPhase.atHub);
  }
}

/// "Scan stock" at the hub once it's packed (Refill 03 → Stock 01).
class StartScanning {
  const StartScanning(this._repository);

  final ShiftRepository _repository;

  Future<void> call(String uid, Shift shift) async {
    if (shift.stockRequest != StockRequestStatus.ready) {
      throw const AppException();
    }
    await _repository.setPhase(uid, shift.id, ShiftPhase.scanning);
  }
}

/// Records scanned portions; with [confirm], all scanned loads the scooter
/// (Stock 06 → Shift 09).
class RecordStockScans {
  const RecordStockScans(this._repository);

  final ShiftRepository _repository;

  Future<void> call(String uid, Shift shift, int scanned, {bool confirm = false}) async {
    final total = shift.stock.portions;
    // A refill's scans count against its own load (ConfirmStock), not the day's.
    final refilling = shift.refill != null;
    if (confirm && !refilling && scanned < total) throw const AppException();
    if (shift.phase.isBefore(ShiftPhase.scanning)) {
      await _repository.setPhase(uid, shift.id, ShiftPhase.scanning);
    }
    if (!refilling) await _repository.recordScans(uid, shift.id, scanned.clamp(0, total));
    if (confirm) await _repository.setPhase(uid, shift.id, ShiftPhase.stockLoaded);
  }
}

/// "Go online" (Shift 07, 09, Stock 06). Only after the stock is scanned and
/// confirmed; otherwise Shift 51. Going online needs signal.
class GoOnline {
  const GoOnline(this._repository, this._signal);

  final ShiftRepository _repository;
  final SignalRepository _signal;

  Future<GoOnlineResult> call(String uid, Shift shift) async {
    if (shift.phase.isBefore(ShiftPhase.stockLoaded)) return GoOnlineResult.needsStock;
    if (!await _signal.isOnline()) return GoOnlineResult.noSignal;
    if (shift.phase == ShiftPhase.stockLoaded) {
      await _repository.setPhase(uid, shift.id, ShiftPhase.headingToSpot);
    }
    return GoOnlineResult.headToSpot;
  }
}
