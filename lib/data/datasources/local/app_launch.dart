import 'package:flutter/services.dart';

/// How long ago the phone started the app (Android's process start), so the
/// splash's time counts from the tap, not from when Flutter came up. Zero
/// where the phone can't say (iOS, tests).
Future<Duration> timeSinceAppStart() async {
  try {
    final ms = await const MethodChannel('ninzo/device').invokeMethod<int>('launchElapsed');
    return Duration(milliseconds: ms ?? 0);
  } on Object {
    return Duration.zero;
  }
}
