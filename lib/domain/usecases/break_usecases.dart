import '../entities/rider_settings.dart';
import '../../core/errors/app_exception.dart';
import '../entities/shift.dart';
import '../entities/online_status.dart';
import '../repositories/online_repository.dart';

/// "Start break" (Shift 43 → 44), "+15 min" and "Back online" (Shift 44, 45).
/// Orders stay paused from the start of the break until the rider is back, on
/// time or not.
class TakeBreak {
  const TakeBreak(this._repository, this._clock);

  /// "+15 min".
  static Duration get extension => RiderSettings.current.breakExtension;

  final OnlineRepository _repository;
  final DateTime Function() _clock;

  Future<void> start(String uid, Shift shift, OnlineStatus status, BreakOption option) async {
    if (shift.phase != ShiftPhase.online) throw const AppException();
    if (status.queue.isNotEmpty) throw const AppException();
    await _repository.setBreak(uid, shift.id, BreakState(startedAt: _clock(), length: option.duration));
  }

  Future<void> extend(String uid, String shiftId, BreakState current) => _repository.setBreak(
    uid,
    shiftId,
    BreakState(startedAt: current.startedAt, length: current.length + extension),
  );

  Future<void> end(String uid, String shiftId) => _repository.setBreak(uid, shiftId, null);
}
