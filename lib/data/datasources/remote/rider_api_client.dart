import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/api/api_endpoints.dart';

/// The API's one error shape: `{code, message, retryable}`.
class RiderApiException extends AppException {
  const RiderApiException(this.code, {this.status, this.retryable = false, String? message}) : super(message ?? code);

  /// e.g. `invalid_otp`, `token_expired`. `network` when the server can't be reached.
  final String code;
  final int? status;
  final bool retryable;
}

/// The signed-in rider's tokens, kept on the phone between launches.
class RiderTokens {
  const RiderTokens({required this.access, required this.refresh, required this.riderId, this.phone});

  final String access;
  final String refresh;
  final String riderId;
  final String? phone;
}

abstract interface class RiderTokenStore {
  Future<RiderTokens?> read();
  Future<void> write(RiderTokens tokens);
  Future<void> clear();
}

class PrefsRiderTokenStore implements RiderTokenStore {
  static const _access = 'riderApi.access', _refresh = 'riderApi.refresh', _rider = 'riderApi.riderId';
  static const _phone = 'riderApi.phone';

  @override
  Future<RiderTokens?> read() async {
    final p = await SharedPreferences.getInstance();
    final access = p.getString(_access), refresh = p.getString(_refresh), rider = p.getString(_rider);
    if (access == null || refresh == null || rider == null) return null;
    return RiderTokens(access: access, refresh: refresh, riderId: rider, phone: p.getString(_phone));
  }

  @override
  Future<void> write(RiderTokens tokens) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_access, tokens.access);
    await p.setString(_refresh, tokens.refresh);
    await p.setString(_rider, tokens.riderId);
    if (tokens.phone != null) await p.setString(_phone, tokens.phone!);
  }

  @override
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    for (final key in [_access, _refresh, _rider, _phone]) {
      await p.remove(key);
    }
  }
}

/// Talks to the rider API: adds the token, refreshes it once on a 401 and
/// sends the request again, puts an Idempotency-Key on writes, and turns
/// errors into [RiderApiException].
class RiderApiClient {
  RiderApiClient({http.Client? client, RiderTokenStore? tokens, Future<String> Function()? baseUrl})
    : _client = client ?? http.Client(),
      tokens = tokens ?? PrefsRiderTokenStore(),
      _baseUrl = baseUrl ?? _baseUrlFromApp;

  static const _channel = MethodChannel('ninzo/device');
  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  final RiderTokenStore tokens;
  final Future<String> Function() _baseUrl;
  Future<RiderTokens?>? _refreshing;

  /// `STAGING_API_URL`, ending in `/v1`.
  Future<String> baseUrl() => _baseUrl();

  /// Signed out on purpose or by the server; the app goes back to Login.
  final signedOut = StreamController<void>.broadcast();

  /// `STAGING_API_URL` from `.env`, put in the manifest by the build.
  static Future<String> _baseUrlFromApp() async {
    try {
      final values = await _channel.invokeMethod<Map<Object?, Object?>>('appConfig');
      final url = values?['riderApiUrl'] as String?;
      if (url != null && url.isNotEmpty) return url;
    } on MissingPluginException {
      // Falls through.
    } on PlatformException {
      // Falls through.
    }
    throw const RiderApiException('no_api_url');
  }

  static String newIdempotencyKey() =>
      List.generate(32, (_) => Random.secure().nextInt(16).toRadixString(16)).join();

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  /// [idempotencyKey] sends that key instead of a new one, e.g. an offline
  /// event's id, so the direct call and the queued one count once.
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool auth = true,
    bool idempotent = false,
    String? idempotencyKey,
  }) => _send(
    'POST',
    path,
    body: body,
    auth: auth,
    idempotencyKey: idempotencyKey ?? (idempotent ? newIdempotencyKey() : null),
  );

  Future<Map<String, dynamic>> delete(String path, {bool idempotent = true}) =>
      _send('DELETE', path, idempotencyKey: idempotent ? newIdempotencyKey() : null);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
    String? idempotencyKey,
    bool retried = false,
  }) async {
    final base = await _baseUrl();
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final saved = auth ? await tokens.read() : null;
    if (auth && saved == null) throw const RiderApiException('signed_out', status: 401);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        'Authorization': ?saved == null ? null : 'Bearer ${saved.access}',
        'Idempotency-Key': ?idempotencyKey,
      });
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
    } on SocketException {
      throw const RiderApiException('network', retryable: true);
    } on TimeoutException {
      throw const RiderApiException('network', retryable: true);
    } on http.ClientException {
      throw const RiderApiException('network', retryable: true);
    }
    if (response.statusCode == 401 && auth && !retried) {
      // Refresh once, then send the same request again (same Idempotency-Key).
      if (await _refresh(saved!) == null) throw const RiderApiException('signed_out', status: 401);
      return _send(method, path, query: query, body: body, auth: auth, idempotencyKey: idempotencyKey, retried: true);
    }
    final text = utf8.decode(response.bodyBytes);
    final json = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json is Map<String, dynamic> ? json : {'data': json};
    }
    final error = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    throw RiderApiException(
      error['code'] as String? ?? 'http_${response.statusCode}',
      status: response.statusCode,
      retryable: error['retryable'] as bool? ?? response.statusCode >= 500,
      message: error['message'] as String?,
    );
  }

  /// One refresh at a time; a 401 from the refresh itself means signed out.
  Future<RiderTokens?> _refresh(RiderTokens saved) {
    return _refreshing ??= () async {
      try {
        final json = await _send(
          'POST',
          RiderApiEndpoints.refresh,
          body: {'refresh_token': saved.refresh},
          auth: false,
        );
        final fresh = RiderTokens(
          access: json['access_token'] as String,
          refresh: json['refresh_token'] as String,
          riderId: saved.riderId,
          phone: saved.phone,
        );
        await tokens.write(fresh);
        return fresh;
      } on RiderApiException catch (e) {
        if (e.status == 401) {
          await tokens.clear();
          signedOut.add(null);
          return null;
        }
        rethrow;
      } finally {
        _refreshing = null;
      }
    }();
  }
}
