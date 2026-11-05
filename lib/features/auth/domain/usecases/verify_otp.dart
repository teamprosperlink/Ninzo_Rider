import '../entities/auth_failure.dart';
import '../entities/otp_request.dart';
import '../repositories/auth_repository.dart';
import '../repositories/session_repository.dart';

/// Signs in with the code the rider received and remembers whether to keep
/// them signed in on this phone.
class VerifyOtp {
  const VerifyOtp(this._repo, this._session);

  final AuthRepository _repo;
  final SessionRepository _session;

  Future<void> call({required String verificationId, required String code, bool keepSignedIn = true}) async {
    final otp = code.trim();
    if (otp.length != kLoginCodeLength) throw const AuthFailure(AuthFailureKind.wrongCode);
    await _repo.verifyOtp(verificationId: verificationId, code: otp);
    await signedIn(keepSignedIn: keepSignedIn);
  }

  /// Records a sign-in that happened without a typed code (auto-verified SMS).
  Future<void> signedIn({required bool keepSignedIn}) async {
    await _session.setKeepSignedIn(keepSignedIn);
    await _session.setWasSignedIn(true);
  }
}
