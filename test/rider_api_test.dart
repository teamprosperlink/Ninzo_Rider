import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninzo_rider/data/datasources/remote/push_token_source.dart';
import 'package:ninzo_rider/data/datasources/remote/rider_api.dart';
import 'package:ninzo_rider/data/datasources/remote/rider_api_client.dart';
import 'package:ninzo_rider/data/datasources/remote/server_pushes.dart';
import 'package:ninzo_rider/domain/entities/push_plan.dart';
import 'package:ninzo_rider/domain/entities/shift_push.dart';
import 'package:ninzo_rider/domain/usecases/shift_push_usecases.dart';
import 'package:ninzo_rider/data/repositories/api_auth_repositories.dart';
import 'package:ninzo_rider/domain/entities/auth_failure.dart';

class _MemoryTokens implements RiderTokenStore {
  RiderTokens? saved;

  @override
  Future<RiderTokens?> read() async => saved;

  @override
  Future<void> write(RiderTokens tokens) async => saved = tokens;

  @override
  Future<void> clear() async => saved = null;
}

class _Push implements PushTokenSource {
  @override
  String get platform => 'android';

  @override
  Future<String?> token() async => 'fcm-1';

  @override
  Stream<String> get refreshed => const Stream.empty();

  final pushes = StreamController<Map<String, String>>.broadcast();

  @override
  Stream<Map<String, String>> get messages => pushes.stream;
}

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  const base = 'https://api.test/v1';

  test('Signs in with phone and OTP and keeps the tokens', () async {
    final tokens = _MemoryTokens();
    final seen = <http.Request>[];
    final client = MockClient((request) async {
      seen.add(request);
      return switch (request.url.path) {
        '/v1/auth/otp/request' => _json(200, {'request_id': 'r1', 'expires_in_s': 300, 'resend_after_s': 30}),
        '/v1/auth/otp/verify' => _json(200, {'access_token': 'a1', 'refresh_token': 'f1', 'rider_id': 'rider-9', 'status': 'active'}),
        _ => _json(404, {'code': 'not_found'}),
      };
    });
    final api = RiderApi(RiderApiClient(client: client, tokens: tokens, baseUrl: () async => base));
    final auth = ApiAuthRepository(api);
    final otp = await auth.sendOtp('+919800000090');
    expect(otp.verificationId, 'r1');
    await auth.verifyOtp(verificationId: 'r1', code: '123456');
    expect(tokens.saved!.access, 'a1');
    expect(tokens.saved!.riderId, 'rider-9');
    expect(tokens.saved!.phone, '+919800000090');
    expect(jsonDecode(seen.last.body), {'request_id': 'r1', 'otp': '123456'});
    expect(seen.last.headers.containsKey('Authorization'), isFalse);
  });

  test('Registers the phone for push after sign-in and removes it on sign-out', () async {
    final seen = <http.Request>[];
    final client = MockClient((request) async {
      seen.add(request);
      return switch ((request.method, request.url.path)) {
        ('POST', '/v1/auth/otp/request') => _json(200, {'request_id': 'r1'}),
        ('POST', '/v1/auth/otp/verify') => _json(200, {'access_token': 'a1', 'refresh_token': 'f1', 'rider_id': 'rider-9'}),
        ('POST', '/v1/riders/me/devices') => _json(201, {'device_id': 'dev_1'}),
        ('DELETE', '/v1/riders/me/devices/dev_1') => _json(200, {}),
        ('POST', '/v1/auth/signout') => _json(200, {}),
        _ => _json(404, {'code': 'not_found'}),
      };
    });
    final auth = ApiAuthRepository(
      RiderApi(RiderApiClient(client: client, tokens: _MemoryTokens(), baseUrl: () async => base)),
      push: _Push(),
    );
    await auth.sendOtp('+919800000090');
    await auth.verifyOtp(verificationId: 'r1', code: '123456');
    await pumpEventQueue();
    final register = seen.singleWhere((r) => r.url.path == '/v1/riders/me/devices');
    expect(jsonDecode(register.body), {'platform': 'android', 'push_token': 'fcm-1'});
    expect(register.headers['Idempotency-Key'], isNotNull);
    expect(auth.deviceId, 'dev_1');
    await auth.signOut();
    expect(seen.where((r) => r.method == 'DELETE' && r.url.path == '/v1/riders/me/devices/dev_1'), hasLength(1));
    expect(auth.deviceId, isNull);
  });

  test('Turns the API error codes into the login states', () async {
    Future<AuthFailureKind> kindFor(String code, int status) async {
      final client = MockClient((_) async => _json(status, {'code': code, 'retryable': false}));
      final auth = ApiAuthRepository(RiderApi(RiderApiClient(client: client, tokens: _MemoryTokens(), baseUrl: () async => base)));
      try {
        await auth.verifyOtp(verificationId: 'r1', code: '000000');
      } on AuthFailure catch (e) {
        return e.kind;
      }
      fail('no failure');
    }

    expect(await kindFor('invalid_otp', 400), AuthFailureKind.wrongCode);
    expect(await kindFor('otp_expired', 400), AuthFailureKind.codeExpired);
    expect(await kindFor('otp_attempts_exceeded', 429), AuthFailureKind.tooManyAttempts);
    expect(await kindFor('account_blocked', 403), AuthFailureKind.onHold);
  });

  test('On a 401 it refreshes once and sends the request again', () async {
    final tokens = _MemoryTokens()..saved = const RiderTokens(access: 'old', refresh: 'f1', riderId: 'rider-9');
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (request.url.path == '/v1/auth/refresh') {
        return _json(200, {'access_token': 'new', 'refresh_token': 'f2', 'expires_in_s': 900});
      }
      return request.headers['Authorization'] == 'Bearer new'
          ? _json(200, {'rider': {'id': 'rider-9', 'name': 'Ravi', 'status': 'active', 'zone_id': null}})
          : _json(401, {'code': 'token_expired'});
    });
    final api = RiderApi(RiderApiClient(client: client, tokens: tokens, baseUrl: () async => base));
    final json = await api.getRider();
    expect((json['rider'] as Map)['name'], 'Ravi');
    expect(tokens.saved!.access, 'new');
    expect(tokens.saved!.refresh, 'f2');
    expect(calls, 3);
  });

  test('A 401 from the refresh signs the rider out', () async {
    final tokens = _MemoryTokens()..saved = const RiderTokens(access: 'old', refresh: 'f1', riderId: 'rider-9');
    final client = MockClient((_) async => _json(401, {'code': 'token_expired'}));
    final rider = RiderApiClient(client: client, tokens: tokens, baseUrl: () async => base);
    final signedOut = expectLater(rider.signedOut.stream, emits(null));
    await expectLater(RiderApi(rider).getRider(), throwsA(isA<RiderApiException>().having((e) => e.code, 'code', 'signed_out')));
    expect(tokens.saved, isNull);
    await signedOut;
  });

  test('Writes carry an Idempotency-Key, kept on the retry after a refresh', () async {
    final tokens = _MemoryTokens()..saved = const RiderTokens(access: 'old', refresh: 'f1', riderId: 'rider-9');
    final keys = <String?>[];
    final client = MockClient((request) async {
      if (request.url.path == '/v1/auth/refresh') return _json(200, {'access_token': 'new', 'refresh_token': 'f2'});
      keys.add(request.headers['Idempotency-Key']);
      return request.headers['Authorization'] == 'Bearer new' ? _json(200, {'shift': {}}) : _json(401, {'code': 'token_expired'});
    });
    await RiderApi(RiderApiClient(client: client, tokens: tokens, baseUrl: () async => base)).endShift();
    expect(keys, hasLength(2));
    expect(keys.first, isNotNull);
    expect(keys.first, keys.last);
  });

  test("The rider API's pushes are shown by kind; the phone doesn't schedule them too", () async {
    final source = _Push();
    final pushes = FcmServerPushes(source);
    final got = <ShiftPush>[];
    final listening = pushes.arrived.listen(got.add);
    for (final data in [
      {'topic': 'push.rider', 'kind': 'notification', 'notification_kind': 'stock_ready'},
      {'topic': 'push.rider', 'kind': 'notification', 'notification_kind': 'shift_ending_soon'},
      {'topic': 'push.rider', 'kind': 'notification', 'notification_kind': 'stock_request'},
      {'topic': 'push.rider', 'kind': 'offer'},
      {'topic': 'push.customer', 'kind': 'notification', 'notification_kind': 'stock_ready'},
    ]) {
      source.pushes.add(data);
    }
    await pumpEventQueue();
    expect(got, [ShiftPush.stockReady, ShiftPush.shiftEndingSoon]);
    await listening.cancel();

    final plan = PushPlan(
      schedule: {ShiftPush.shiftEndingSoon: DateTime(2026), ShiftPush.prepareStock: DateTime(2026)},
      showNow: {ShiftPush.spotAssigned, ShiftPush.awayFromSpot},
    );
    final filtered = WatchServerPushes(pushes).withoutServerSent(plan);
    expect(filtered.schedule.keys, [ShiftPush.prepareStock]);
    expect(filtered.showNow, {ShiftPush.awayFromSpot});
    expect(WatchServerPushes(const NoServerPushes()).withoutServerSent(plan).schedule, hasLength(2));
  });
}
