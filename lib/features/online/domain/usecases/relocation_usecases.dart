import '../../../shift/domain/entities/shift.dart';
import '../../../shift/domain/repositories/shift_repository.dart';
import '../entities/online_status.dart';
import '../repositories/online_repository.dart';

/// The backend's nudge to a spot where orders wait (Shift 36–39). The system
/// assigns spots, one rider each: taking the nudge makes it the rider's spot.
class AnswerRelocation {
  const AnswerRelocation(this._online, this._shifts, this._clock);

  final OnlineRepository _online;
  final ShiftRepository _shifts;
  final DateTime Function() _clock;

  /// "Navigate to spot" (Shift 36 → 37). The paid time runs from here.
  Future<void> accept(String uid, Shift shift, RelocationNudge nudge) async {
    await _online.setNudge(uid, shift.id, nudge.accepted(_clock()));
    await _shifts.setSpot(uid, shift.id, nudge.spot);
    await _shifts.setPhase(uid, shift.id, ShiftPhase.headingToSpot);
  }

  /// "Not now" (Shift 36), "Got it" (Shift 39) → Shift 26.
  Future<void> dismiss(String uid, String shiftId) => _online.setNudge(uid, shiftId, null);
}
