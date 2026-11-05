import '../../domain/entities/app_user.dart';

/// Firestore shape of `users/{uid}`.
class AppUserModel extends AppUser {
  const AppUserModel({required super.uid, required super.phone, required super.name, super.email});

  factory AppUserModel.fromEntity(AppUser u) => AppUserModel(uid: u.uid, phone: u.phone, name: u.name, email: u.email);

  factory AppUserModel.fromFirestore(String uid, Map<String, dynamic> j) => AppUserModel(
        uid: uid,
        phone: j['phone'] as String,
        name: j['name'] as String,
        email: j['email'] as String?,
      );

  Map<String, Object?> toFirestore() => {'phone': phone, 'name': name, 'email': email};
}
