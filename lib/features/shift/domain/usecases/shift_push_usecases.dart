import '../entities/shift.dart';
import '../entities/shift_push.dart';
import '../repositories/shift_notifier.dart';

/// Sets up the phone's pushes; says what the app was launched from, if a push.
class InitPushes {
  const InitPushes(this._notifier);

  final ShiftNotifier _notifier;

  Future<({ShiftPushAction? action, ShiftPush? push})> call() async {
    final action = await _notifier.init();
    return (action: action, push: _notifier.launchedFrom);
  }
}

/// Actions the rider taps on a push while the app runs.
class WatchPushActions {
  const WatchPushActions(this._notifier);

  final ShiftNotifier _notifier;

  Stream<ShiftPushAction> call() => _notifier.actions;
}

/// Pushes the rider opens by tapping them while the app runs.
class WatchOpenedPushes {
  const WatchOpenedPushes(this._notifier);

  final ShiftNotifier _notifier;

  Stream<ShiftPush> call() => _notifier.opened;
}

class SchedulePush {
  const SchedulePush(this._notifier);

  final ShiftNotifier _notifier;

  Future<void> call(ShiftPush push, Shift shift, DateTime at) => _notifier.schedule(push, shift, at);
}

class ShowPush {
  const ShowPush(this._notifier);

  final ShiftNotifier _notifier;

  Future<void> call(ShiftPush push, Shift shift, {PushDetail detail = const PushDetail()}) =>
      _notifier.show(push, shift, detail: detail);
}

class CancelPush {
  const CancelPush(this._notifier);

  final ShiftNotifier _notifier;

  Future<void> call(ShiftPush push) => _notifier.cancel(push);
}
