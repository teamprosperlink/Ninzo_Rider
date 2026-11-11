import '../../core/errors/app_exception.dart';

/// Why signing in failed. Each kind has its own state in the login designs.
enum AuthFailureKind {
  /// Not a 10-digit Indian mobile number (Login 14).
  invalidNumber,

  /// No rider account for this number (Login 03).
  notRegistered,

  /// The rider account is on hold (Login 16).
  onHold,

  /// No connection (Login 12).
  noInternet,

  /// The code doesn't match (Login 06).
  wrongCode,

  /// The code is too old; a new one is needed (Login 11).
  codeExpired,

  /// Too many tries; sign-in is paused (Login 10).
  tooManyAttempts,

  /// Anything else.
  unknown,
}

class AuthFailure extends AppException {
  const AuthFailure(this.kind, [super.reason]);

  final AuthFailureKind kind;
}
