import '../../core/utils/validators.dart';
import '../entities/auth_failure.dart';
import '../entities/otp_request.dart';
import '../entities/rider_account_info.dart';
import '../repositories/auth_repository.dart';
import '../repositories/rider_directory.dart';
import '../../core/constants/app_strings.dart';

/// A code was sent (or the phone verified itself) for a known rider.
class LoginCodeRequest {
  const LoginCodeRequest(this.otp, this.account);

  final OtpRequest otp;
  final RiderAccountInfo? account;
}

/// Sends a login code to a 10-digit Indian mobile number (without +91).
///
/// Signing in needs an existing rider account that isn't on hold. Pass the
/// [previous] request to resend.
class RequestLoginCode {
  const RequestLoginCode(this._auth, this._directory);

  final AuthRepository _auth;
  final RiderDirectory _directory;

  Future<LoginCodeRequest> call(String phone, {OtpRequest? previous}) async {
    phone = phone.trim();
    if (!Validators.isMobile(phone)) throw const AuthFailure(AuthFailureKind.invalidNumber);
    final e164 = AppStrings.indiaPhone(phone);
    final account = await _directory.find(e164);
    if (account == null) throw const AuthFailure(AuthFailureKind.notRegistered);
    if (account.onHold) throw const AuthFailure(AuthFailureKind.onHold);
    final otp = await _auth.sendOtp(e164, resendToken: previous?.resendToken);
    return LoginCodeRequest(otp, account);
  }
}
