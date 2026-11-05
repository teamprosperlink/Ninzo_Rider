import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_state_providers.dart';
import '../../../shift/di/shift_di.dart';
import '../../../shift/domain/usecases/shift_flow_usecases.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../../shift/presentation/viewmodels/shift_flow_view_model.dart';
import '../../di/online_di.dart';
import '../../domain/entities/spot_option.dart';
import '../../domain/usecases/choose_spot_usecases.dart';

/// Shift 13–18: one screen by stage. [choosing] is Shift 14 until a spot is
/// selected, then Shift 15.
enum ChooseSpotStage { finding, choosing, confirming, spotFull, noSpot }

class ChooseSpotState {
  const ChooseSpotState({this.stage = ChooseSpotStage.finding, this.spots = const [], this.selected, this.filled});

  final ChooseSpotStage stage;
  final List<SpotOption> spots;

  /// The spot the button goes to.
  final SpotOption? selected;

  /// The spot that just filled up (Shift 17).
  final SpotOption? filled;
}

class ChooseSpotViewModel extends Notifier<ChooseSpotState> {
  static const _retryAfter = Duration(seconds: 5);

  var _all = const <SpotOption>[];
  var _run = 0;
  Timer? _retry;

  @override
  ChooseSpotState build() {
    ref.onDispose(() => _retry?.cancel());
    return const ChooseSpotState();
  }

  ShiftFlowViewModel get _flow => ref.read(shiftFlowViewModelProvider.notifier);

  /// Shift 13. Nothing in the flow map leads here yet: the demo pill does.
  void open() {
    _flow.show(ShiftScreen.chooseSpot);
    find();
  }

  /// Shift 13, also from "Refresh" (Shift 17) and "Check again" (Shift 18).
  Future<void> find() async {
    final run = ++_run;
    _retry?.cancel();
    state = const ChooseSpotState();
    try {
      final spots = await ref.read(findSpotsUseCaseProvider)(ref.read(currentUidProvider)!);
      if (!ref.mounted || run != _run) return;
      _all = spots;
      state = SpotChoiceRules.anyFree(spots)
          ? ChooseSpotState(stage: ChooseSpotStage.choosing, spots: spots)
          : const ChooseSpotState(stage: ChooseSpotStage.noSpot);
    } catch (_) {
      // No frame for this: Shift 13 stays, and looks again by itself.
      if (ref.mounted && run == _run) _retry = Timer(_retryAfter, find);
    }
  }

  /// Shift 14 → 15. A full spot can't be picked.
  void select(SpotOption spot) {
    if (state.stage != ChooseSpotStage.choosing || spot.isFull) return;
    state = ChooseSpotState(stage: ChooseSpotStage.choosing, spots: _all, selected: spot);
  }

  /// "Go to …" (Shift 15, 17) → Shift 16 → Shift 19.
  Future<void> confirm() async {
    final spot = state.selected;
    final shift = ref.read(todayShiftProvider).value;
    if (spot == null || shift == null || state.stage == ChooseSpotStage.confirming) return;
    final uid = ref.read(currentUidProvider)!;
    final run = ++_run;
    state = ChooseSpotState(stage: ChooseSpotStage.confirming, spots: _all, selected: spot);
    final stayOnChoice = ChooseSpotState(stage: ChooseSpotStage.choosing, spots: _all, selected: spot);
    try {
      final result = await ref.read(confirmSpotUseCaseProvider)(uid, shift, spot);
      if (!ref.mounted || run != _run) return;
      if (result == ConfirmSpotResult.spotFull) return spotFilled(spot);
      ref.read(demoRiderLocationProvider)?.changeSpot(spot.point, spot.km * 1000);
      switch (await ref.read(goOnlineUseCaseProvider)(uid, shift)) {
        case GoOnlineResult.headToSpot:
          _flow.show(null);
        case GoOnlineResult.needsStock:
          _flow.show(ShiftScreen.stockEmpty);
        // No frame for this: the choice stays as it was.
        case GoOnlineResult.noSignal:
          state = stayOnChoice;
      }
    } catch (_) {
      // No frame for this: the choice stays as it was.
      if (ref.mounted && run == _run) state = stayOnChoice;
    }
  }

  /// Shift 17: [spot] just filled up. With nothing else free, Shift 18.
  void spotFilled(SpotOption spot) {
    ++_run;
    final filled = spot.filled;
    _all = [
      for (final s in _all)
        if (s.name == filled.name) filled else s,
    ];
    if (!SpotChoiceRules.anyFree(_all)) {
      state = const ChooseSpotState(stage: ChooseSpotStage.noSpot);
      return;
    }
    final spots = SpotChoiceRules.afterFilled(_all, filled);
    state = ChooseSpotState(stage: ChooseSpotStage.spotFull, spots: spots, selected: spots[1], filled: filled);
  }

  /// The back arrow. It waits while a spot is being confirmed.
  void back() {
    if (state.stage == ChooseSpotStage.confirming) return;
    ++_run;
    _retry?.cancel();
    _flow.home();
  }
}

final chooseSpotViewModelProvider = NotifierProvider<ChooseSpotViewModel, ChooseSpotState>(ChooseSpotViewModel.new);
