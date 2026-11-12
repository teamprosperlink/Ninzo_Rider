import '../entities/push_plan.dart';
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

/// The rider API's own pushes, arriving while the app is open, and which
/// kinds it sends (so the phone doesn't schedule those too).
class WatchServerPushes {
  const WatchServerPushes(this._pushes);

  final ServerPushes _pushes;

  Stream<ShiftPush> call() => _pushes.arrived;

  /// [plan] without what the server sends itself.
  PushPlan withoutServerSent(PushPlan plan) {
    if (!_pushes.active) return plan;
    return PushPlan(
      schedule: {
        for (final MapEntry(:key, :value) in plan.schedule.entries)
          if (!ShiftPush.fromServer.contains(key)) key: value,
      },
      cancel: plan.cancel,
      showNow: plan.showNow.difference(ShiftPush.fromServer),
      detail: plan.detail,
    );
  }
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
