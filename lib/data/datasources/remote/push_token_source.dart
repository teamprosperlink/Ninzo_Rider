import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

/// The phone's push token, for `POST /riders/me/devices`.
abstract interface class PushTokenSource {
  /// "android" or "ios".
  String get platform;

  /// The token, or null when push isn't available (no permission, no Google
  /// Play services).
  Future<String?> token();

  /// A new token after the old one was replaced.
  Stream<String> get refreshed;

  /// Pushes from the rider API that arrive while the app is open, as their
  /// data. (With the app closed the phone shows them itself.)
  Stream<Map<String, String>> get messages;
}

/// Firebase Cloud Messaging: the token the rider API sends pushes to, and
/// the pushes that arrive while the app is open.
class FirebasePushTokenSource implements PushTokenSource {
  const FirebasePushTokenSource();

  @override
  String get platform => Platform.isIOS ? 'ios' : 'android';

  @override
  Future<String?> token() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      // The backend sends to the FCM registration token, not the newer
      // installation id.
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } on Object {
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get refreshed => FirebaseMessaging.instance.onTokenRefresh;

  @override
  Stream<Map<String, String>> get messages =>
      FirebaseMessaging.onMessage.map((m) => {for (final MapEntry(:key, :value) in m.data.entries) key: '$value'});
}
