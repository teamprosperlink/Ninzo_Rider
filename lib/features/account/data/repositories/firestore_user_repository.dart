import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/firebase_error_mapper.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/app_user_model.dart';

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  @override
  Stream<AppUser?> watchUser(String uid) => _doc(uid).snapshots().map((s) {
        final j = s.data();
        return j == null ? null : AppUserModel.fromFirestore(uid, j);
      });

  @override
  Future<void> createUser(AppUser user) => guardFirebase(() => _doc(user.uid).set({
        ...AppUserModel.fromEntity(user).toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      }));

  @override
  Future<void> updateProfile(String uid, {required String name, String? email}) => guardFirebase(() =>
      _doc(uid).update({'name': name, 'email': email, 'updatedAt': FieldValue.serverTimestamp()}));
}
