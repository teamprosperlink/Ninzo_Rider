import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../../core/error/firebase_error_mapper.dart';
import '../../domain/entities/rider_application.dart';
import '../../domain/entities/rider_area.dart';
import '../../domain/entities/rider_document.dart';
import '../../domain/repositories/registration_repository.dart';
import '../models/rider_application_model.dart';

/// Applications live in `riders/{uid}`, photos in Storage under
/// `kyc/{uid}/{document}_{side}.jpg`. The number is listed in
/// `riderPhones/{+91…}` (read before sign-in by the login and register
/// screens).
///
/// TODO(backend): map the area to a hub (`hubLabel`), review documents (set
/// `status` and each document's `issue`), and on approval set `firstShift`,
/// `spot` and the directory's `hubLabel` / `shiftStart`; SMS the rider.
class FirebaseRegistrationRepository implements RegistrationRepository {
  FirebaseRegistrationRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('riders').doc(uid);

  @override
  Stream<RiderApplication?> watch(String uid) => _doc(uid).snapshots().map((s) {
    final j = s.data();
    return j == null ? null : RiderApplicationModel.fromFirestore(uid, j);
  });

  @override
  Future<void> saveDetails({
    required String uid,
    required String phone,
    required String name,
    required RiderArea area,
  }) => guardFirebase(() async {
    final ref = _doc(uid);
    final details = {'name': name, 'area': RiderAreaModel.toApplication(area)};
    if ((await ref.get()).exists) {
      await ref.update({...details, 'updatedAt': FieldValue.serverTimestamp()});
    } else {
      await ref.set({
        ...details,
        'phone': phone,
        'status': RegistrationStatus.draft.name,
        'documents': <String, Object?>{},
        'welcomed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    final listing = _db.collection('riderPhones').doc(phone);
    if (!(await listing.get()).exists) {
      await listing.set({
        'uid': uid,
        'onHold': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  });

  @override
  Future<String> uploadPhoto({
    required String uid,
    required RiderDocument document,
    required DocumentSide side,
    required String filePath,
  }) => guardFirebase(() async {
    final ref = _storage.ref('kyc/$uid/${document.name}_${side.name}.jpg');
    await ref.putFile(
      File(filePath),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  });

  @override
  Future<void> saveDocuments(
    String uid,
    Map<RiderDocument, DocumentUpload> documents,
  ) => guardFirebase(
    () => _doc(uid).update({
      'documents': RiderApplicationModel.documentsToFirestore(documents),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> reopen(String uid) => guardFirebase(
    () => _doc(uid).update({
      'status': RegistrationStatus.draft.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> submit(String uid) => guardFirebase(
    () => _doc(uid).update({
      'status': RegistrationStatus.underReview.name,
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<void> markWelcomed(String uid) => guardFirebase(
    () => _doc(uid)
        .update({'welcomed': true, 'updatedAt': FieldValue.serverTimestamp()}),
  );
}
