import '../entities/shift.dart';

/// The rider's shifts. The backend creates each day's shift (time, hub,
/// spot, scooter) and moves the hub's side of the stock request (accepted,
/// packed); the rider replies to the request and moves their phase forward.
abstract interface class ShiftRepository {
  /// Today's shift, or null when the rider has none; updates live.
  Stream<Shift?> watchToday(String uid);

  /// The rider's reply: [StockRequestStatus.requested] ("I'm coming", "Ask
  /// hub to prepare") or [StockRequestStatus.notWorkingToday].
  Future<void> replyToStockRequest(String uid, String shiftId, StockRequestStatus reply);

  /// Moves the rider's day to [phase].
  Future<void> setPhase(String uid, String shiftId, ShiftPhase phase);

  /// Starts or ends a refill, moving to [phase] in one go.
  Future<void> setRefill(
    String uid,
    String shiftId, {
    required RefillLoad? refill,
    required int round,
    required ShiftPhase phase,
  });

  /// The rider's spot from now on (Shift 37).
  Future<void> setSpot(String uid, String shiftId, Spot spot);

  /// Portions scanned onto the scooter so far.
  Future<void> recordScans(String uid, String shiftId, int scanned);
}
