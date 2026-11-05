import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/firebase_error_mapper.dart';
import '../../domain/repositories/shift_end_repositories.dart';

/// `openOn` on the shift says which phone holds it; `endedAt` when it ended.
///
/// TODO(backend): sign the other phone out when `openOn` changes (Shift 54).
class FirestoreShiftSessionRepository implements ShiftSessionRepository {
  FirestoreShiftSessionRepository(this._db);

  static const _deviceKey = 'shift_device_id';

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String shiftId) =>
      _db.collection('riders').doc(uid).collection('shifts').doc(shiftId);

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_deviceKey);
    if (saved != null) return saved;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join();
    await prefs.setString(_deviceKey, id);
    return id;
  }

  @override
  Future<bool> openElsewhere(String uid, String shiftId) => guardFirebase(() async {
    final open = (await _doc(uid, shiftId).get()).data()?['openOn'] as String?;
    return open != null && open != await _deviceId();
  });

  @override
  Future<void> claim(String uid, String shiftId) async {
    final device = await _deviceId();
    await guardFirebase(
      () => _doc(uid, shiftId).update({'openOn': device, 'updatedAt': FieldValue.serverTimestamp()}),
    );
  }

  @override
  Future<void> markEnded(String uid, String shiftId) => guardFirebase(
    () => _doc(uid, shiftId).update({'endedAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()}),
  );
}

/// The demo's other phone, which the Home pill opens the shift on.
class DemoShiftSessionRepository implements ShiftSessionRepository {
  bool otherPhone = false;

  @override
  Future<bool> openElsewhere(String uid, String shiftId) async => otherPhone;

  @override
  Future<void> claim(String uid, String shiftId) async => otherPhone = false;

  @override
  Future<void> markEnded(String uid, String shiftId) async {}
}
