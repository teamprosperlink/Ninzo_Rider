import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/auth_failure.dart';
import '../../domain/entities/rider_account_info.dart';
import '../../domain/repositories/rider_directory.dart';

/// Reads `riderPhones/{+91XXXXXXXXXX}`: `{onHold: bool, hubLabel, shiftStart}`.
///
/// TODO(backend): keep this index in sync with `riders/{uid}` (e.g. a Cloud
/// Function on rider approval / hold) and allow unauthenticated `get` (not
/// `list`) on it in the security rules. A number without a document is
/// treated as "not a rider account yet" (Login 03).
class FirestoreRiderDirectory implements RiderDirectory {
  FirestoreRiderDirectory(this._db);

  final FirebaseFirestore _db;

  @override
  Future<RiderAccountInfo?> find(String phoneNumber) async {
    try {
      final snap = await _db.collection('riderPhones').doc(phoneNumber).get();
      final j = snap.data();
      if (j == null) return null;
      return RiderAccountInfo(
        onHold: j['onHold'] == true,
        hubLabel: j['hubLabel'] as String?,
        shiftStart: j['shiftStart'] as String?,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        throw const AuthFailure(AuthFailureKind.noInternet);
      }
      throw AuthFailure(AuthFailureKind.unknown, e.code);
    }
  }
}
