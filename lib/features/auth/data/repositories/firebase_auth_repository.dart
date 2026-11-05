import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/auth_failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/otp_request.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map((u) => u == null ? null : AuthUser(uid: u.uid, phone: u.phoneNumber ?? ''));

  @override
  Future<OtpRequest> sendOtp(String phoneNumber, {int? resendToken}) {
    final completer = Completer<OtpRequest>();
    void fail(Object e) {
      if (!completer.isCompleted) completer.completeError(_mapError(e));
    }

    _auth
        .verifyPhoneNumber(
          phoneNumber: phoneNumber,
          forceResendingToken: resendToken,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credential) async {
            try {
              await _auth.signInWithCredential(credential);
              if (!completer.isCompleted) completer.complete(const OtpRequest.autoVerified());
            } on Object catch (e) {
              fail(e);
            }
          },
          verificationFailed: fail,
          codeSent: (id, token) {
            if (!completer.isCompleted) completer.complete(OtpRequest(verificationId: id, resendToken: token));
          },
          codeAutoRetrievalTimeout: (_) {},
        )
        .catchError(fail);
    return completer.future;
  }

  @override
  Future<void> verifyOtp({required String verificationId, required String code}) async {
    try {
      await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code));
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  /// Anonymous account: the application keeps the number, the user has none.
  @override
  Future<void> signInNewRider(String phoneNumber) async {
    try {
      await _auth.signInAnonymously();
    } on Object catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Maps Firebase errors to the login states in the design.
  static AuthFailure _mapError(Object e) {
    if (e is AuthFailure) return e;
    if (e is! FirebaseAuthException) return const AuthFailure(AuthFailureKind.unknown);
    final kind = switch (e.code) {
      'invalid-verification-code' || 'invalid-verification-id' => AuthFailureKind.wrongCode,
      'session-expired' || 'code-expired' => AuthFailureKind.codeExpired,
      'invalid-phone-number' => AuthFailureKind.invalidNumber,
      'too-many-requests' || 'quota-exceeded' => AuthFailureKind.tooManyAttempts,
      'network-request-failed' => AuthFailureKind.noInternet,
      'user-disabled' => AuthFailureKind.onHold,
      _ => AuthFailureKind.unknown,
    };
    return AuthFailure(kind, e.code);
  }
}
