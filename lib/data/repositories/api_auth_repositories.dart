import 'dart:async';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/otp_request.dart';
import '../../domain/entities/rider_account_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/rider_directory.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/remote/push_token_source.dart';
import '../datasources/remote/rider_api.dart';
import '../datasources/remote/rider_api_client.dart';

/// Phone and OTP sign-in against the rider API. The phone is registered
/// for push after every sign-in (`POST /riders/me/devices`) and removed on
/// sign-out (`DELETE /riders/me/devices/{id}`).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, {this.push}) {
    _signedOut = _api.client.signedOut.stream.listen((_) => _changes.add(null));
    _pushRefreshed = push?.refreshed.listen((token) async {
      if (await _tokens.read() != null) await _registerDevice(token);
    }, onError: (Object _) {});
  }

  final RiderApi _api;
  /// Where the push token comes from; none in tests.
  final PushTokenSource? push;
  StreamSubscription<String>? _pushRefreshed;

  /// The id `POST /riders/me/devices` gave this phone.
  String? deviceId;
  final _changes = StreamController<AuthUser?>.broadcast();
  late final StreamSubscription<void> _signedOut;
  String? _phone;

  RiderTokenStore get _tokens => _api.client.tokens;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    final saved = await _tokens.read();
    // Signed in from before: the token may have changed since.
    if (saved != null) unawaited(_registerDevice());
    yield saved == null ? null : AuthUser(uid: saved.riderId, phone: saved.phone ?? '');
    yield* _changes.stream;
  }

  @override
  Future<OtpRequest> sendOtp(String phoneNumber, {int? resendToken}) async {
    try {
      final json = await _api.requestOtp(phoneNumber);
      _phone = phoneNumber;
      return OtpRequest(verificationId: json['request_id'] as String);
    } on RiderApiException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> verifyOtp({required String verificationId, required String code}) async {
    try {
      final json = await _api.verifyOtp(verificationId, code);
      final tokens = RiderTokens(
        access: json['access_token'] as String,
        refresh: json['refresh_token'] as String,
        riderId: json['rider_id'] as String,
        phone: _phone,
      );
      await _tokens.write(tokens);
      unawaited(_registerDevice());
      _changes.add(AuthUser(uid: tokens.riderId, phone: tokens.phone ?? ''));
    } on RiderApiException catch (e) {
      throw _failure(e);
    }
  }

  /// The API signs new riders in with an OTP too; there's no sign-in without one.
  @override
  Future<void> signInNewRider(String phoneNumber) async => throw const AuthFailure(AuthFailureKind.unknown);

  /// Registering a token the server has already updates it.
  Future<void> _registerDevice([String? known]) async {
    final push = this.push;
    if (push == null) return;
    final token = known ?? await push.token();
    if (token == null) return;
    try {
      final json = await _api.registerDevice({'platform': push.platform, 'push_token': token});
      deviceId = json['device_id'] as String? ?? deviceId;
      _api.deviceId = deviceId;
    } on RiderApiException {
      // Next sign-in or launch tries again.
    }
  }

  @override
  Future<void> signOut() async {
    final device = deviceId;
    if (device != null) {
      try {
        await _api.removeDevice(device);
      } on RiderApiException {
        // Signing out ends the session anyway; the server drops its devices.
      }
      deviceId = null;
      _api.deviceId = null;
    }
    try {
      await _api.signOut();
    } on RiderApiException {
      // The session ends on this phone either way.
    }
    await _tokens.clear();
    _changes.add(null);
  }

  static AuthFailure _failure(RiderApiException e) => AuthFailure(switch (e.code) {
    'invalid_otp' => AuthFailureKind.wrongCode,
    'otp_expired' => AuthFailureKind.codeExpired,
    'otp_attempts_exceeded' || 'rate_limited' => AuthFailureKind.tooManyAttempts,
    'account_blocked' => AuthFailureKind.onHold,
    'network' => AuthFailureKind.noInternet,
    'validation_failed' || 'invalid_phone' => AuthFailureKind.invalidNumber,
    _ => AuthFailureKind.unknown,
  }, e.code, e.retryAfter);

  void dispose() {
    _signedOut.cancel();
    _pushRefreshed?.cancel();
    _changes.close();
  }
}

/// The API never says whether a number has an account (a failed sign-in
/// looks the same), so every number gets a code.
class ApiRiderDirectory implements RiderDirectory {
  const ApiRiderDirectory();

  @override
  Future<RiderAccountInfo?> find(String phoneNumber) async => const RiderAccountInfo();
}

/// The rider's profile from `GET /riders/me`.
class ApiUserRepository implements UserRepository {
  ApiUserRepository(this._api);

  final RiderApi _api;

  final _updates = StreamController<AppUser>.broadcast();

  static AppUser _user(Map<String, dynamic> rider, String? phone) => AppUser(
    uid: rider['id'] as String,
    phone: phone ?? '',
    name: rider['name'] as String? ?? '',
    email: rider['email'] as String?,
  );

  @override
  Stream<AppUser?> watchUser(String uid) async* {
    final saved = await _api.client.tokens.read();
    final json = await _api.getRider();
    yield _user(json['rider'] as Map<String, dynamic>, saved?.phone);
    yield* _updates.stream;
  }

  /// The account exists once operations have added the number; creating
  /// one here gives it its name (`PATCH /riders/me`).
  @override
  Future<void> createUser(AppUser user) => _patch({'name': user.name, 'email': ?user.email});

  @override
  Future<void> updateProfile(String uid, {required String name, String? email}) => _patch({'name': name, 'email': email});

  Future<void> _patch(Map<String, dynamic> changes) async {
    try {
      final json = await _api.updateRider(changes);
      final saved = await _api.client.tokens.read();
      _updates.add(_user(json['rider'] as Map<String, dynamic>, saved?.phone));
    } on RiderApiException catch (e) {
      throw AuthFailure(e.code == 'network' ? AuthFailureKind.noInternet : AuthFailureKind.unknown, e.code);
    }
  }
}
