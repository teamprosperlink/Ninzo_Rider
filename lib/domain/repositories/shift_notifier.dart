import '../entities/shift.dart';
import '../entities/shift_push.dart';

/// The pushes the rider API sends (FCM) that arrive while the app is open.
abstract interface class ServerPushes {
  /// True when the rider API sends [ShiftPush.fromServer] itself.
  bool get active;

  Stream<ShiftPush> get arrived;
}

/// Shows the shift's push notifications on the phone. With the rider API,
/// the server sends [ShiftPush.fromServer] and this shows the stock request
/// (with its replies) at the plan's times and "away from your spot".
abstract interface class ShiftNotifier {
  /// Sets up the channel and returns the action the app was opened with,
  /// if it was launched from a push.
  Future<ShiftPushAction?> init();

  /// Shows [push] at [at] (now if it's in the past).
  Future<void> schedule(ShiftPush push, Shift shift, DateTime at);

  /// Shows [push] now.
  Future<void> show(ShiftPush push, Shift shift, {PushDetail detail = const PushDetail()});

  Future<void> cancel(ShiftPush push);

  /// Pushes and actions the rider taps while the app runs.
  Stream<ShiftPushAction> get actions;

  /// A push the rider opened by tapping it while the app runs.
  Stream<ShiftPush> get opened;

  /// The push that launched the app; known after [init].
  ShiftPush? get launchedFrom;
}
