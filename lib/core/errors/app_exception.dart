/// An expected failure: a broken rule or no connection. Never shown to the
/// rider (the app only says what a Figma frame says); callers catch it and leave
/// the screen as it was. [reason] is for logs and tests only.
class AppException implements Exception {
  const AppException([this.reason]);

  final String? reason;

  @override
  String toString() => reason ?? 'AppException';
}

/// [AppException.reason]s a use case acts on.
abstract final class AppErrorReasons {
  /// The backend still has an order on this rider ("Can't end shift yet").
  static const orderInProgress = 'order_in_progress';
}
