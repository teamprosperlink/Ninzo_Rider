import '../../../account/domain/entities/app_user.dart';
import '../../../account/domain/repositories/user_repository.dart';
import '../../../../core/error/app_exception.dart';
import '../entities/rider_area.dart';
import '../repositories/registration_repository.dart';

/// Saves the verified rider's details (Register 01–02) as a draft
/// application, and their profile (`users/{uid}`).
class SaveRegistrationDetails {
  const SaveRegistrationDetails(this._registration, this._users);

  final RegistrationRepository _registration;
  final UserRepository _users;

  Future<void> call({
    required String uid,
    required String phone,
    required String name,
    required RiderArea? area,
  }) async {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      throw const AppException();
    }
    if (area == null) throw const AppException();
    await _registration.saveDetails(
      uid: uid,
      phone: phone,
      name: trimmed,
      area: area,
    );
    await _users.createUser(AppUser(uid: uid, phone: phone, name: trimmed));
  }
}
