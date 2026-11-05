import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../models/profile_models.dart';

/// TODO(backend): set `spot.assignedAt` when assigning a spot, and write
/// `riders/{uid}/notifications/{id}` with each push it sends.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._db);

  /// Enough for a rider's last week, whatever else is in there.
  static const _shiftLimit = 14;
  static const _notificationLimit = 50;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _rider(String uid) => _db.collection('riders').doc(uid);

  @override
  Stream<ProfileFacts> watchFacts(String uid) => _rider(uid).snapshots().map((s) => profileFactsFromFirestore(s.data()));

  @override
  Stream<List<RiderNotification>> watchNotifications(String uid) => _rider(uid)
      .collection('notifications')
      .orderBy('at', descending: true)
      .limit(_notificationLimit)
      .snapshots()
      .map((s) => [for (final doc in s.docs) riderNotificationFromFirestore(doc.id, doc.data())]);

  @override
  Stream<List<ShiftRecord>> watchShifts(String uid) => _rider(uid)
      .collection('shifts')
      .orderBy(FieldPath.documentId, descending: true)
      .limit(_shiftLimit)
      .snapshots()
      .map((s) => [for (final doc in s.docs) shiftRecordFromFirestore(doc.id, doc.data())]);
}
