/// Result of asking for an OTP. On Android the SMS can be read
/// automatically, in which case the user is already signed in.
class OtpRequest {
  const OtpRequest({required this.verificationId, this.resendToken});

  const OtpRequest.autoVerified() : verificationId = null, resendToken = null;

  final String? verificationId;
  final int? resendToken;

  bool get isAutoVerified => verificationId == null;
}

/// Length of the SMS code.
const kLoginCodeLength = 6;
