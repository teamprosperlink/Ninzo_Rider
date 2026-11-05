import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/firebase_error_mapper.dart';
import '../../domain/entities/shift.dart';
import '../../domain/repositories/shift_repository.dart';
import '../models/shift_model.dart';

/// Shifts live in `riders/{uid}/shifts/{yyyy-MM-dd}` (see [ShiftModel]).
///
/// TODO(backend): create each day's shift (times, hub, spot, scooter, stock
/// load); send the 1-hour push and the 30-minute reminder through FCM and
/// set `awaitingReply`; when the rider says yes, have the hub accept
/// (`packing`, `stockReadyAt`) and finish (`ready`).
class FirestoreShiftRepository implements ShiftRepository {
  FirestoreShiftRepository(this._db, this._clock);

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String shiftId) =>
      _db.collection('riders').doc(uid).collection('shifts').doc(shiftId);

  @override
  Stream<Shift?> watchToday(String uid) {
    final id = Shift.idFor(_clock());
    return _doc(uid, id).snapshots().map((s) {
      final j = s.data();
      return j == null ? null : ShiftModel.fromFirestore(id, j);
    });
  }

  @override
  Future<void> replyToStockRequest(String uid, String shiftId, StockRequestStatus reply) => guardFirebase(
    () => _doc(uid, shiftId).update({
      'stockRequest': reply.name,
      'repliedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> setPhase(String uid, String shiftId, ShiftPhase phase) =>
      guardFirebase(() => _doc(uid, shiftId).update({'phase': phase.name, 'updatedAt': FieldValue.serverTimestamp()}));

  @override
  Future<void> setRefill(
    String uid,
    String shiftId, {
    required RefillLoad? refill,
    required int round,
    required ShiftPhase phase,
  }) => guardFirebase(
    () => _doc(uid, shiftId).update({
      'refill': refill == null ? FieldValue.delete() : {'hubName': refill.hubName},
      'refillRound': round,
      'phase': phase.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> setSpot(String uid, String shiftId, Spot spot) => guardFirebase(
    () => _doc(uid, shiftId).update({
      'spot': {'name': spot.name, 'lat': spot.point.latitude, 'lng': spot.point.longitude},
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> recordScans(String uid, String shiftId, int scanned) => guardFirebase(
    () => _doc(uid, shiftId).update({'stock.scanned': scanned, 'updatedAt': FieldValue.serverTimestamp()}),
  );
}
