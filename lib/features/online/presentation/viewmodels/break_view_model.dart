import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/clock_provider.dart';
import '../../../auth/presentation/providers/auth_state_providers.dart';
import '../../../shift_end/presentation/viewmodels/end_shift_view_model.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../../shift/presentation/viewmodels/shift_flow_view_model.dart';
import '../../di/online_di.dart';
import '../../domain/entities/online_status.dart';
import '../providers/online_providers.dart';

class BreakUiState {
  const BreakUiState({this.option = BreakOption.min30, this.busy = false});

  /// Shift 43's choice.
  final BreakOption option;
  final bool busy;
}

/// Shift 43–45. The break itself lives in the online status, so it survives a
/// restart.
class BreakViewModel extends Notifier<BreakUiState> {
  @override
  BreakUiState build() {
    // Starts afresh for each rider.
    ref.watch(currentUidProvider);
    return const BreakUiState();
  }

  Shift? get _shift => ref.read(todayShiftProvider).value;
  OnlineStatus get _status => ref.read(onlineStatusProvider).value ?? const OnlineStatus();
  String get _uid => ref.read(currentUidProvider)!;
  ShiftFlowViewModel get _flow => ref.read(shiftFlowViewModelProvider.notifier);

  void select(BreakOption option) => state = BreakUiState(option: option, busy: state.busy);

  Future<void> _run(Future<void> Function(Shift shift) command) async {
    final shift = _shift;
    if (shift == null || state.busy) return;
    state = BreakUiState(option: state.option, busy: true);
    try {
      await command(shift);
    } catch (_) {
      // No frame for this: the screen stays as it was.
    } finally {
      if (ref.mounted) state = BreakUiState(option: state.option);
    }
  }

  /// "Start break" (Shift 43) → 44.
  Future<void> start() => _run((shift) async {
    await ref.read(takeBreakUseCaseProvider).start(_uid, shift, _status, state.option);
    _flow.show(null);
  });

  /// "Cancel" (Shift 43) → the map.
  void cancel() => _flow.show(null);

  /// "+15 min" (Shift 44, 45).
  Future<void> addTime() => _run((shift) async {
    final current = _status.breakState;
    if (current != null) await ref.read(takeBreakUseCaseProvider).extend(_uid, shift.id, current);
  });

  /// "Back online" (Shift 44, 45) → 26.
  Future<void> backOnline() => _run((shift) => ref.read(takeBreakUseCaseProvider).end(_uid, shift.id));

  /// "End shift" (Shift 44, 45) → 48.
  void endShift() => ref.read(endShiftViewModelProvider.notifier).open();

  /// The demo's "Time up" pill: the break of [length] has just run out.
  void demoTimeUp(Duration length) {
    final repository = ref.read(demoOnlineProvider);
    if (repository == null) return;
    repository.set(
      repository.status.copyWith(
        breakState: () => BreakState(startedAt: ref.read(clockProvider)().subtract(length), length: length),
      ),
    );
  }
}

final breakViewModelProvider = NotifierProvider<BreakViewModel, BreakUiState>(BreakViewModel.new);
