import '../entities/auth_user.dart';
import '../entities/otp_request.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();

  /// Sends an OTP to [phoneNumber] (E.164 format).
  Future<OtpRequest> sendOtp(String phoneNumber, {int? resendToken});

  Future<void> verifyOtp({required String verificationId, required String code});

  /// Signs in a new rider without a code (Register 02 "Continue"); the
  /// number isn't verified, it's only remembered as [phoneNumber].
  Future<void> signInNewRider(String phoneNumber);

  Future<void> signOut();
}
