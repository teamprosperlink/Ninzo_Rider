import 'package:flutter/services.dart';

import '../../../core/errors/app_exception.dart';

/// The key the map uses, read from the app's own manifest, and the headers
/// Google's web services want for a key limited to this app.
class GoogleApi {
  static const _channel = MethodChannel('ninzo/device');

  Map<String, String>? _headers;

  Future<Map<String, String>> headers() async {
    final cached = _headers;
    if (cached != null) return cached;
    final Map<Object?, Object?>? values;
    try {
      values = await _channel.invokeMethod<Map<Object?, Object?>>('googleApi');
    } on MissingPluginException {
      throw const AppException();
    } on PlatformException {
      throw const AppException();
    }
    final key = values?['key'] as String?;
    if (key == null || key.isEmpty) throw const AppException();
    return _headers = {
      'X-Goog-Api-Key': key,
      'X-Android-Package': values?['package'] as String? ?? '',
      'X-Android-Cert': values?['sha1'] as String? ?? '',
    };
  }

  Future<String> key() async => (await headers())['X-Goog-Api-Key']!;
}
