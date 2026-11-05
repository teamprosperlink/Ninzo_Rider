import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/clock_provider.dart';
import '../../../auth/presentation/providers/auth_state_providers.dart';
import '../../../intro/di/intro_di.dart';
import '../../../intro/domain/entities/app_permission.dart';
import '../../../online/di/online_di.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../shift/domain/entities/route_step.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../../stock/di/stock_di.dart';
import '../../di/orders_di.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/usecases/delivery_usecases.dart';

/// The order the rider started, live.
final activeOrderProvider = StreamProvider<DeliveryOrder?>((ref) {
  final id = ref.watch(onlineStatusProvider.select((s) => s.value?.activeOrderId));
  if (id == null) return Stream.value(null);
  return ref.watch(watchDeliveryOrderUseCaseProvider)(id);
});

final _orderTickProvider = StreamProvider.autoDispose<int>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (i) => i),
);

/// The current time; the screens with the 90 s clock rebuild every second.
DateTime watchOrderTime(WidgetRef ref) {
  ref.watch(_orderTickProvider);
  return ref.read(clockProvider)();
}

/// What the rider is looking at within an order's status. Figma's frames are
/// states of fewer screens:
///
/// * [main]: the order map (Order 01 assigned; Order 02, 03 and Navigate 01–03
///   on the way) and, by status, the result screen (Order 05, Arrival 03,
///   Navigate 04–06)
/// * [skip]: Order 04 over Order 01
/// * [gate]: Arrival 01, 02, 04
/// * [handover]: past Arrival 03
enum OrderStep { main, skip, gate, handover }

class OrderFlowState {
  const OrderFlowState({
    this.step = OrderStep.main,
    this.reason = SkipReason.scooterProblem,
    this.position,
    this.route,
    this.signal = true,
    this.reportedIssue,
    this.notConfirmed = false,
    this.cameraOn = true,
    this.busy = false,
  });

  final OrderStep step;

  /// Order 04's choice.
  final SkipReason reason;

  /// The rider, when known.
  final LatLng? position;

  /// The next turn.
  final RouteStep? route;
  final bool signal;
  final RouteIssue? reportedIssue;

  /// Arrival 02: the gate's QR code or code didn't match.
  final bool notConfirmed;

  /// Arrival 04 when off.
  final bool cameraOn;
  final bool busy;

  /// Navigate 01–03.
  RouteIssue? get issue => routeIssueOf(signal: signal, reported: reportedIssue);

  OrderFlowState copyWith({
    OrderStep? step,
    SkipReason? reason,
    LatLng? position,
    RouteStep? route,
    bool? signal,
    RouteIssue? Function()? reportedIssue,
    bool? notConfirmed,
    bool? cameraOn,
    bool? busy,
  }) => OrderFlowState(
    step: step ?? this.step,
    reason: reason ?? this.reason,
    position: position ?? this.position,
    route: route ?? this.route,
    signal: signal ?? this.signal,
    reportedIssue: reportedIssue == null ? this.reportedIssue : reportedIssue(),
    notConfirmed: notConfirmed ?? this.notConfirmed,
    cameraOn: cameraOn ?? this.cameraOn,
    busy: busy ?? this.busy,
  );
}

/// One order from assignment to the gate (Order 01–05, Arrival 01–04, Navigate
/// 01–06). Follows the rider and the route, and moves to where the buttons
/// lead. The status comes from the backend, so a cancellation shows wherever
/// the rider is.
class OrderFlowViewModel extends Notifier<OrderFlowState> {
  final _subs = <StreamSubscription<Object?>>[];
  bool _demoCameraOff = false;

  @override
  OrderFlowState build() {
    // Starts afresh for each order.
    final id = ref.watch(onlineStatusProvider.select((s) => s.value?.activeOrderId));
    ref.onDispose(() {
      for (final sub in _subs) {
        sub.cancel();
      }
      _subs.clear();
    });
    if (id != null) {
      _subs.add(ref.read(watchRiderPositionUseCaseProvider)().listen(_onPosition, onError: (Object _) {}));
      _subs.add(
        ref
            .read(watchRouteIssueUseCaseProvider)()
            .listen((issue) => state = state.copyWith(reportedIssue: () => issue), onError: (Object _) {}),
      );
      _subs.add(ref.read(watchSignalUseCaseProvider)().listen((online) => state = state.copyWith(signal: online)));
      ref.read(checkSignalUseCaseProvider)().then((online) {
        if (ref.mounted) state = state.copyWith(signal: online);
      });
      ref.listen(activeOrderProvider, (_, _) => _refreshRoute());
    }
    return const OrderFlowState();
  }

  DeliveryOrder? get _order => ref.read(activeOrderProvider).value;

  void _onPosition(LatLng position) {
    state = state.copyWith(position: position);
    _refreshRoute();
    final order = _order;
    if (order != null) ref.read(shareOrderLocationUseCaseProvider)(order, position);
  }

  Future<void> _refreshRoute() async {
    final order = _order, position = state.position;
    if (order == null || position == null) return;
    final route = await ref.read(nextGateStepUseCaseProvider)(position, order.gate.point);
    if (ref.mounted) state = state.copyWith(route: route);
  }

  Future<void> _run(Future<void> Function(DeliveryOrder order) command) async {
    final order = _order;
    if (order == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await command(order);
      if (ref.mounted) state = state.copyWith(busy: false);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// Order 01 "Navigate to Gate 3" → Order 02.
  Future<void> navigate() => _run((order) => ref.read(startNavigationUseCaseProvider)(order));

  /// Order 01 "Skip this order" → Order 04.
  void askSkip() => state = state.copyWith(step: OrderStep.skip);

  /// Order 04 "Keep this order" → Order 01.
  void keepOrder() => state = state.copyWith(step: OrderStep.main);

  void selectReason(SkipReason reason) => state = state.copyWith(reason: reason);

  /// Order 04 "Submit" → Order 05.
  Future<void> skip() => _run((order) async {
    await ref.read(skipOrderUseCaseProvider)(order, state.reason);
    if (ref.mounted) state = state.copyWith(step: OrderStep.main);
  });

  /// "I've reached the gate" → Arrival 01.
  Future<void> reachedGate() => _run((order) async {
    await ref.read(reachGateUseCaseProvider)(order);
    if (!ref.mounted) return;
    state = state.copyWith(step: OrderStep.gate, notConfirmed: false);
    await _checkCamera(ask: true);
  });

  /// Back on Arrival 02 → 01; on 01, 04 → the map.
  void backFromGate() {
    if (state.notConfirmed) {
      scanAgain();
    } else {
      state = state.copyWith(step: OrderStep.main);
    }
  }

  /// Arrival 02 "Scan QR again" → 01.
  void scanAgain() => state = state.copyWith(notConfirmed: false);

  /// A code from the camera.
  Future<void> onGateCode(String code) => _confirm(GateMethod.qr, code);

  /// "Enter gate code" (no Figma frame for it).
  Future<void> submitGateCode(String code) => _confirm(GateMethod.code, code);

  Future<void> _confirm(GateMethod method, String proof) => _run((order) async {
    final confirmed = await ref.read(confirmGateUseCaseProvider)(order, method, proof);
    if (ref.mounted) state = state.copyWith(notConfirmed: !confirmed);
  });

  // ── Camera (Arrival 04) ──

  Future<void> _checkCamera({bool ask = false}) async {
    var result = await ref.read(checkPermissionUseCaseProvider)(AppPermission.camera);
    if (ask && result == PermissionResult.denied) {
      result = await ref.read(requestPermissionUseCaseProvider)(AppPermission.camera);
    }
    if (ref.mounted) state = state.copyWith(cameraOn: result == PermissionResult.granted && !_demoCameraOff);
  }

  /// Camera access may have changed in the phone's settings.
  Future<void> recheckCamera() => _checkCamera();

  /// Tapping the viewfinder with the camera off.
  Future<void> turnOnCamera() async {
    final result = await ref.read(requestPermissionUseCaseProvider)(AppPermission.camera);
    if (result == PermissionResult.blocked) await ref.read(openPermissionSettingsUseCaseProvider)(AppPermission.camera);
    await _checkCamera();
  }

  /// The camera failed to start, or the phone has none.
  void cameraFailed() {
    if (ref.mounted && state.cameraOn) state = state.copyWith(cameraOn: false);
  }

  /// Demo mode: no real gate to point at, so each tap "scans" one.
  void demoScan() => onGateCode(ref.read(demoDeliveryProvider)!.nextScan());

  /// The demo's "Camera" pill.
  Future<void> demoSetCameraOff(bool off) async {
    _demoCameraOff = off;
    if (off) {
      state = state.copyWith(cameraOn: false);
    } else {
      await _checkCamera(ask: true);
    }
  }

  /// Arrival 03 "Hand over order" → Handover 01.
  void handOver() => state = state.copyWith(step: OrderStep.handover);

  /// Back from Handover 01 → Arrival 03.
  void backToGateConfirmed() => state = state.copyWith(step: OrderStep.main);

  /// "Start next order" (Handover 11) → Order 02 of the next order.
  Future<void> startNext() => _run((order) async {
    final shift = ref.read(todayShiftProvider).value;
    final status = ref.read(onlineStatusProvider).value;
    if (shift == null || status == null) return;
    await ref.read(startNextOrderUseCaseProvider)(ref.read(currentUidProvider)!, shift, status, order.id);
  });

  /// "Back to your spot" (Order 05, Navigate 04–06), "Back to waiting"
  /// (Handover 06) → the map.
  Future<void> backToSpot() => _run((order) async {
    final shift = ref.read(todayShiftProvider).value;
    if (shift == null) return;
    await ref.read(finishOrderUseCaseProvider)(ref.read(currentUidProvider)!, shift, order.id);
  });
}

final orderFlowViewModelProvider = NotifierProvider<OrderFlowViewModel, OrderFlowState>(OrderFlowViewModel.new);
