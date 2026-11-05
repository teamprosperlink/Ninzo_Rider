import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/domain/repositories/rider_directory.dart';
import '../../../../core/utils/validators.dart';
import '../entities/register_failure.dart';

/// Register 02 → "Continue" while signed out: checks the number has no rider
/// account yet (Register 03), then signs the new rider in without a code.
class StartRegistration {
  const StartRegistration(this._directory, this._auth);

  final RiderDirectory _directory;
  final AuthRepository _auth;

  /// [phone] is the 10 digits after +91.
  Future<void> call(String phone) async {
    phone = phone.trim();
    if (!Validators.isMobile(phone)) {
      throw const RegisterFailure(RegisterFailureKind.invalidNumber);
    }
    final e164 = '+91$phone';
    if (await _directory.find(e164) != null) {
      throw const RegisterFailure(RegisterFailureKind.alreadyRegistered);
    }
    await _auth.signInNewRider(e164);
  }
}
