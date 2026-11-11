import '../entities/restock.dart';
import '../entities/online_status.dart';

/// The online rider's backend. The backend drives quiet spells, the battery,
/// the stats and the order queue; the rider goes online, adds time and starts
/// orders.
abstract interface class OnlineRepository {
  /// Updates live.
  Stream<OnlineStatus> watch(String uid, String shiftId);

  /// Stamps when the rider first went online at the spot.
  Future<void> markOnline(String uid, String shiftId);

  /// Moves the shift's end (Add time).
  Future<void> setShiftEnd(String uid, String shiftId, DateTime end);

  /// "Start order" (Shift 28 → Order 01).
  Future<void> startOrder(String uid, String shiftId, AssignedOrder order);

  /// A break starts, moves or ends (null).
  Future<void> setBreak(String uid, String shiftId, BreakState? state);

  /// The rider's answer to a nudge; null clears it.
  Future<void> setNudge(String uid, String shiftId, RelocationNudge? nudge);

  /// The rider's answer to a restock; null clears it.
  Future<void> setRestock(String uid, String shiftId, RestockRequest? restock);

  /// A refill's portions join the scooter's.
  Future<void> addStock(String uid, String shiftId, int portions);

  /// "Back to your spot" (Order 05, Navigate 04–06), "Back to waiting"
  /// (Handover 06, 10) → the map; "Start next order" (Handover 11) moves on to
  /// [thenStart] in one go.
  Future<void> finishOrder(String uid, String shiftId, String orderId, {String? thenStart});
}
