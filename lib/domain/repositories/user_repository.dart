import '../entities/app_user.dart';

abstract interface class UserRepository {
  /// The user's profile, or null until they finish sign-up.
  Stream<AppUser?> watchUser(String uid);

  Future<void> createUser(AppUser user);

  Future<void> updateProfile(String uid, {required String name, String? email});
}
