import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/demo_data.dart';
import '../../../auth/presentation/providers/auth_state_providers.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../../shift/domain/entities/route_step.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../../shift/presentation/viewmodels/shift_flow_view_model.dart';
import '../../di/online_di.dart';
import '../../domain/usecases/spot_usecases.dart';
import '../providers/online_providers.dart';

/// Where the rider is on the way to being online. Several Figma frames are
/// states of one screen:
///
/// * [overview]: Shift 19, 20 (items list open)
/// * [heading]: Shift 21, 22 (almost there), by the distance left
/// * [confirm]: Shift 23
/// * [checking]: Shift 24
enum SpotStage { overview, heading, confirm, checking }

class GoOnlineState {
  const GoOnlineState({
    this.stage = SpotStage.overview,
    this.itemsOpen = false,
    this.position,
    this.step,
  });

  final SpotStage stage;
  final bool itemsOpen;

  /// The rider, when known.
  final LatLng? position;

  /// Next turn and distance left.
  final RouteStep? step;

  GoOnlineState copyWith({
    SpotStage? stage,
    bool? itemsOpen,
    LatLng? position,
    RouteStep? step,
  }) => GoOnlineState(
    stage: stage ?? this.stage,
    itemsOpen: itemsOpen ?? this.itemsOpen,
    position: position ?? this.position,
    step: step ?? this.step,
  );
}

/// Shift 19–24: follows the rider to the spot. Reaching it asks them to
/// confirm; confirming checks the location and takes them online.
class GoOnlineViewModel extends Notifier<GoOnlineState> {
  /// "Not yet, still on the way" while within reach: ask again after this.
  static const askAgainAfter = Duration(seconds: 20);

  /// So "Checking your location…" can be read.
  static const checkAtLeast = Duration(milliseconds: 900);

  StreamSubscription<LatLng>? _sub;
  Timer? _askAgain;
  bool _snoozed = false;

  @override
  GoOnlineState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _askAgain?.cancel();
    });
    _sub = ref.watch(watchRiderPositionUseCaseProvider)().listen(_onPosition, onError: (Object _) {});
    // Keeps the status live: a provider nobody listens to is paused.
    ref.listen(onlineStatusProvider, (_, _) {});
    // Sent back from the main map (Shift 30 → 21): straight to the route.
    // A nudge taken (Shift 37) opens on its own overview instead.
    final status = ref.read(onlineStatusProvider).value;
    final returning = status?.onlineAt != null && status?.nudge == null;
    if (returning) ref.read(demoRiderLocationProvider)?.ride();
    return GoOnlineState(stage: returning ? SpotStage.heading : SpotStage.overview);
  }

  Shift? get _shift => ref.read(todayShiftProvider).value;

  /// The demo's "Move 240 m away" pill.
  void demoMoveAway() => ref.read(demoRiderLocationProvider)?.moveTo(DemoData.riderAlmostMeters);

  Future<void> _onPosition(LatLng position) async {
    final shift = _shift;
    if (shift == null) return;
    state = state.copyWith(position: position);
    _checkArrived();
    final step = await ref.read(nextSpotStepUseCaseProvider)(position, shift.spot.point);
    if (ref.mounted) state = state.copyWith(step: step);
  }

  void _checkArrived() {
    final shift = _shift;
    final position = state.position;
    if (shift == null || position == null || state.stage != SpotStage.heading) return;
    final proximity = SpotRules.proximity(SpotRules.metersBetween(position, shift.spot.point));
    if (proximity != SpotProximity.atSpot) {
      _snoozed = false;
      _askAgain?.cancel();
    } else if (!_snoozed) {
      state = state.copyWith(stage: SpotStage.confirm);
    }
  }

  /// Shift 19 ↔ 20.
  void toggleItems() => state = state.copyWith(itemsOpen: !state.itemsOpen);

  /// Shift 19 "Navigate to spot" → 21.
  void navigate() {
    state = state.copyWith(stage: SpotStage.heading, itemsOpen: false);
    ref.read(demoRiderLocationProvider)?.ride();
    _checkArrived();
  }

  /// Shift 23 "Not yet, still on the way".
  void notYet() {
    _snoozed = true;
    state = state.copyWith(stage: SpotStage.heading);
    _askAgain?.cancel();
    _askAgain = Timer(askAgainAfter, () {
      _snoozed = false;
      _checkArrived();
    });
  }

  /// Shift 23 "Yes, I'm at the spot" → 24 → 25, or 22 when clearly elsewhere.
  Future<void> confirm() async {
    final shift = _shift;
    if (shift == null || state.stage == SpotStage.checking) return;
    state = state.copyWith(stage: SpotStage.checking);
    try {
      final results = await Future.wait([
        ref.read(checkAtSpotUseCaseProvider)(shift.spot),
        Future<void>.delayed(checkAtLeast),
      ]);
      if (!ref.mounted) return;
      final check = results.first as SpotCheck;
      switch (check) {
        case SpotTooFar(:final position):
          _snoozed = false;
          state = state.copyWith(stage: SpotStage.heading, position: position);
          ref.read(demoRiderLocationProvider)?.ride();
        case SpotConfirmed():
          await _goOnline(shift);
      }
    } catch (_) {
      if (ref.mounted) state = state.copyWith(stage: SpotStage.confirm);
    }
  }

  Future<void> _goOnline(Shift shift) async {
    final confirmed = ref.read(spotJustConfirmedProvider.notifier);
    confirmed.start();
    final status = ref.read(onlineStatusProvider).value;
    final result = await ref.read(goOnlineAtSpotUseCaseProvider)(
      ref.read(currentUidProvider)!,
      shift,
      status ?? (await ref.read(onlineStatusProvider.future)),
    );
    if (result == GoOnlineAtSpotResult.noSignal && ref.mounted) {
      confirmed.cancel();
      // No frame for this: back on Shift 23, as it was.
      state = state.copyWith(stage: SpotStage.confirm);
    }
  }

  /// Back: 21 → 19 → Home. Coming back to the spot, Home isn't an option.
  void back() {
    switch (state.stage) {
      case SpotStage.overview:
        // Moving to a new spot, Home isn't an option either.
        if (ref.read(onlineStatusProvider).value?.nudge == null) {
          ref.read(shiftFlowViewModelProvider.notifier).home();
        }
      case SpotStage.heading:
        final status = ref.read(onlineStatusProvider).value;
        if (status?.onlineAt == null || status?.nudge != null) {
          state = state.copyWith(stage: SpotStage.overview);
        }
      case SpotStage.confirm:
        notYet();
      case SpotStage.checking:
        break;
    }
  }
}

final goOnlineViewModelProvider = NotifierProvider.autoDispose<GoOnlineViewModel, GoOnlineState>(GoOnlineViewModel.new);
