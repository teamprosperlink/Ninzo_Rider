import 'dart:async';

import '../../core/constants/demo_data.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/otp_request.dart';
import '../../domain/entities/rider_account_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/rider_directory.dart';

/// In-memory phone sign-in for demo mode. Any number gets the code
/// [DemoData.otp]; codes expire after [DemoData.codeLifetime]; after
/// [DemoData.maxWrongCodes] wrong codes sign-in pauses.
class DemoAuthRepository implements AuthRepository {
  AuthUser? _user;
  final _changes = StreamController<AuthUser?>.broadcast();
  String? _phone;
  DateTime? _sentAt;
  var _wrong = 0;
  var _requests = 0;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  Future<OtpRequest> sendOtp(String phoneNumber, {int? resendToken}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_phone != phoneNumber) _wrong = 0;
    _phone = phoneNumber;
    _sentAt = DateTime.now();
    _requests++;
    return OtpRequest(verificationId: 'demo-$_requests', resendToken: _requests);
  }

  @override
  Future<void> verifyOtp({required String verificationId, required String code}) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_wrong >= DemoData.maxWrongCodes) throw const AuthFailure(AuthFailureKind.tooManyAttempts);
    if (DateTime.now().difference(_sentAt!) > DemoData.codeLifetime) {
      throw const AuthFailure(AuthFailureKind.codeExpired);
    }
    if (code != DemoData.otp) {
      _wrong++;
      throw AuthFailure(_wrong >= DemoData.maxWrongCodes ? AuthFailureKind.tooManyAttempts : AuthFailureKind.wrongCode);
    }
    _wrong = 0;
    _changes.add(_user = AuthUser(uid: DemoData.uidFor(_phone!), phone: _phone!));
  }

  @override
  Future<void> signInNewRider(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _changes.add(_user = AuthUser(uid: DemoData.uidFor(phoneNumber), phone: phoneNumber));
  }

  @override
  Future<void> signOut() async => _changes.add(_user = null);
}

/// Sample riders: every number is a rider at Hub 2 except
/// [DemoData.unregisteredNumber]; [DemoData.onHoldNumber] is on hold.
class DemoRiderDirectory implements RiderDirectory {
  @override
  Future<RiderAccountInfo?> find(String phoneNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!DemoData.isRegistered(phoneNumber)) return null;
    return RiderAccountInfo(
      onHold: phoneNumber.endsWith(DemoData.onHoldNumber),
      hubLabel: DemoData.hubLabel,
      shiftStart: DemoData.shiftStart,
    );
  }
}
