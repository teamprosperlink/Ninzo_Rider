/// An expected failure: a broken rule or no connection. Never shown to the
/// rider (the app only says what a Figma frame says); callers catch it and leave
/// the screen as it was. [reason] is for logs and tests only.
class AppException implements Exception {
  const AppException([this.reason]);

  final String? reason;

  @override
  String toString() => reason ?? 'AppException';
}
