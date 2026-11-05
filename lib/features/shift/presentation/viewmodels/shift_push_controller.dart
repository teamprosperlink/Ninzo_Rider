import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/clock_provider.dart';
import '../../../auth/presentation/providers/auth_state_providers.dart';
import '../../../online/di/online_di.dart';
import '../../../online/domain/entities/online_status.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../online/presentation/viewmodels/online_map_view_model.dart';
import '../../di/shift_di.dart';
import '../../domain/entities/shift.dart';
import '../../domain/entities/shift_push.dart';
import '../../domain/usecases/plan_shift_pushes.dart';
import '../providers/shift_providers.dart';
import 'shift_flow_view_model.dart';

/// Keeps the phone's shift pushes in line with today's shift (Notification
/// 01–07), records the rider's reply from a push action and opens the screen a
/// tapped push leads to. `AppGate` keeps
/// it alive, so it also sees the rider signing out.
class ShiftPushController extends Notifier<void> {
  final _scheduled = <ShiftPush, DateTime>{};
  final _clearedOnce = <ShiftPush>{};

  @override
  void build() {
    final sub = ref.watch(watchPushActionsUseCaseProvider)().listen(_onAction);
    ref.onDispose(sub.cancel);
    final opened = ref.watch(watchOpenedPushesUseCaseProvider)().listen(_onOpened);
    ref.onDispose(opened.cancel);
    unawaited(
      ref.watch(initPushesUseCaseProvider)().then((launched) {
        final action = launched.action, push = launched.push;
        if (action != null && ref.mounted) _onAction(action);
        if (push != null && ref.mounted) _onOpened(push);
      }),
    );
    ref.listen<OnlineStatus?>(onlineStatusProvider.select((s) => s.value), (previous, status) {
      final shift = ref.read(todayShiftProvider).value;
      if (shift != null && status != null) _applyOnline(shift, shift, previous, status);
    });
    ref.listen<double?>(onlineMapViewModelProvider.select((s) => s.metersFromSpot), (previous, meters) {
      final shift = ref.read(todayShiftProvider).value;
      if (shift == null || meters == null) return;
      final status = ref.read(onlineStatusProvider).value ?? const OnlineStatus();
      _run(ref.read(planOnlinePushesUseCaseProvider).onPosition(shift, status, previous, meters), shift);
    });
    ref.listen<Shift?>(todayShiftProvider.select((s) => s.value), (previous, shift) {
      if (shift != null) {
        _apply(shift, previous);
        final status = ref.read(onlineStatusProvider).value ?? const OnlineStatus();
        _applyOnline(previous, shift, status, status);
      } else if (previous != null) {
        // Signed out: no pushes left behind. (Not while the shift is still
        // loading: the rider may be about to answer one.)
        _cancelAll();
      }
    }, fireImmediately: true);
  }

  Future<void> _apply(Shift shift, Shift? previous) async {
    final cancel = ref.read(cancelPushUseCaseProvider);
    final schedule = ref.read(schedulePushUseCaseProvider);
    final show = ref.read(showPushUseCaseProvider);
    final plan = ref.read(planShiftPushesUseCaseProvider)(shift, ref.read(clockProvider)(), previous: previous);
    // Unconditionally: an alarm may be left from before the app restarted.
    for (final push in plan.cancel) {
      _scheduled.remove(push);
      await cancel(push);
    }
    for (final MapEntry(key: push, value: at) in plan.schedule.entries) {
      if (_scheduled[push] == at) continue;
      _scheduled[push] = at;
      await schedule(push, shift, at);
    }
    for (final push in plan.showNow) {
      await show(push, shift);
    }
  }

  void _applyOnline(Shift? previousShift, Shift shift, OnlineStatus? previous, OnlineStatus status) => _run(
    ref
        .read(planOnlinePushesUseCaseProvider)
        .call(shift, status, ref.read(clockProvider)(), previousShift: previousShift, previous: previous),
    shift,
  );

  Future<void> _run(PushPlan plan, Shift shift) async {
    final cancel = ref.read(cancelPushUseCaseProvider);
    final schedule = ref.read(schedulePushUseCaseProvider);
    final show = ref.read(showPushUseCaseProvider);
    for (final push in plan.cancel) {
      // Once unconditionally: an alarm may be left from before the app restarted.
      if (_scheduled.remove(push) != null || _clearedOnce.add(push)) await cancel(push);
    }
    for (final MapEntry(key: push, value: at) in plan.schedule.entries) {
      if (_scheduled[push] == at) continue;
      _scheduled[push] = at;
      await schedule(push, shift, at);
    }
    for (final push in plan.showNow) {
      await show(push, shift, detail: plan.detail);
    }
  }

  /// A tapped push leads where the flow map draws it.
  void _onOpened(ShiftPush push) {
    if (!ref.mounted) return;
    final flow = ref.read(shiftFlowViewModelProvider.notifier);
    switch (push) {
      case ShiftPush.spotAssigned:
        flow.show(ShiftScreen.profileSpot);
      case ShiftPush.shiftEndingSoon:
      case ShiftPush.awayFromSpot:
        flow.show(null);
      case ShiftPush.ordersWaiting:
        flow.home();
      case ShiftPush.prepareStock:
      case ShiftPush.reminder:
      case ShiftPush.stockReady:
        break;
    }
  }

  Future<void> _cancelAll() async {
    final cancel = ref.read(cancelPushUseCaseProvider);
    _scheduled.clear();
    for (final push in ShiftPush.values) {
      await cancel(push);
    }
  }

  Future<void> _onAction(ShiftPushAction action) async {
    if (action == ShiftPushAction.open) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    try {
      // Opened from a push: the shift may still be loading.
      final shift = ref.read(todayShiftProvider).value ?? await ref.read(todayShiftProvider.future);
      if (shift == null || !ref.mounted) return;
      await ref.read(replyToStockRequestUseCaseProvider)(uid, shift, coming: action == ShiftPushAction.coming);
    } catch (_) {
      // Already packing: Home shows where things stand.
    }
  }
}

final shiftPushControllerProvider = NotifierProvider<ShiftPushController, void>(ShiftPushController.new);
