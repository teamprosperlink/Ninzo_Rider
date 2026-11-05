import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/firebase_error_mapper.dart';
import '../../../refill/domain/entities/restock.dart';
import '../../domain/entities/online_status.dart';
import '../../domain/repositories/online_repository.dart';
import '../models/online_status_model.dart';

/// Reads and writes the online fields of the shift (see [OnlineStatusModel]).
///
/// TODO(backend): assign orders to `queue` when the rider is at the spot,
/// keep `today`, `stock.sold`, `scooter.batteryPercent` and `quietSpell` up to
/// date, and send the "away from spot" and "shift ending" pushes.
class FirestoreOnlineRepository implements OnlineRepository {
  FirestoreOnlineRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String shiftId) =>
      _db.collection('riders').doc(uid).collection('shifts').doc(shiftId);

  @override
  Stream<OnlineStatus> watch(String uid, String shiftId) => _doc(uid, shiftId).snapshots().map((s) {
    final j = s.data();
    return j == null ? const OnlineStatus() : OnlineStatusModel.fromFirestore(j);
  });

  @override
  Future<void> markOnline(String uid, String shiftId) => guardFirebase(
    () => _doc(
      uid,
      shiftId,
    ).update({'onlineAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()}),
  );

  @override
  Future<void> setShiftEnd(String uid, String shiftId, DateTime end) => guardFirebase(
    () => _doc(uid, shiftId).update({'end': Timestamp.fromDate(end), 'updatedAt': FieldValue.serverTimestamp()}),
  );

  @override
  Future<void> startOrder(String uid, String shiftId, AssignedOrder order) => guardFirebase(
    () => _doc(uid, shiftId).update({'activeOrderId': order.id, 'updatedAt': FieldValue.serverTimestamp()}),
  );

  @override
  Future<void> setBreak(String uid, String shiftId, BreakState? state) => guardFirebase(
    () => _doc(uid, shiftId).update({
      'break': state == null ? FieldValue.delete() : OnlineStatusModel.breakToMap(state),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  /// TODO(backend): write `nudge` when orders wait at a spot with no rider,
  /// set it `covered` when another rider takes it, and pay the ride.
  @override
  Future<void> setNudge(String uid, String shiftId, RelocationNudge? nudge) => guardFirebase(
    () => _doc(uid, shiftId).update({
      'nudge': nudge == null ? FieldValue.delete() : OnlineStatusModel.nudgeToMap(nudge),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  /// TODO(backend): write `restock` when suggesting one, and fill in the queue
  /// slot, arrival time and packing once the rider confirms.
  @override
  Future<void> setRestock(String uid, String shiftId, RestockRequest? restock) => guardFirebase(
    () => _doc(uid, shiftId).update({
      'restock': restock == null ? FieldValue.delete() : OnlineStatusModel.restockToMap(restock),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  /// TODO(backend): keep `itemsLeft` up to date as orders are delivered.
  @override
  Future<void> addStock(String uid, String shiftId, int portions) => guardFirebase(
    () => _doc(uid, shiftId).update({
      'stock.added': FieldValue.increment(portions),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  /// TODO(backend): take the order out of `queue` when it's skipped, cancelled
  /// or delivered, stamp the next one's `assignedAt` and pay the trip.
  @override
  Future<void> finishOrder(String uid, String shiftId, String orderId, {String? thenStart}) => guardFirebase(
    () => _doc(
      uid,
      shiftId,
    ).update({'activeOrderId': thenStart ?? FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()}),
  );
}
