import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock_provider.dart';
import '../../auth/providers/auth_state_providers.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/online_status.dart';
import '../../online/providers/online_providers.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../../domain/entities/shift_end.dart';
import '../../../core/constants/app_durations.dart';

/// The sheet over the scrim. Several Figma frames are states of one screen:
///
/// * [limit]: Shift 46
/// * [confirm]: Shift 48
/// * [ending]: Shift 49
/// * [blocked]: Shift 47
enum EndShiftStage { limit, confirm, ending, blocked }

class EndShiftState {
  const EndShiftState({this.stage = EndShiftStage.confirm, this.endedAt});

  final EndShiftStage stage;

  /// When the rider ended it on this phone; the summary's clock stops here.
  final DateTime? endedAt;
}

/// Shift 46–49: asks, then ends the shift. The phase then shows Shift 50.
class EndShiftViewModel extends Notifier<EndShiftState> {

  @override
  EndShiftState build() {
    // Starts afresh for each rider.
    ref.watch(currentUidProvider);
    return const EndShiftState();
  }

  Shift? get _shift => ref.read(todayShiftProvider).value;
  OnlineStatus get _status => ref.read(onlineStatusProvider).value ?? const OnlineStatus();
  String get _uid => ref.read(currentUidProvider)!;
  ShiftFlowViewModel get _flow => ref.read(shiftFlowViewModelProvider.notifier);

  void _showSheet(EndShiftStage stage) {
    state = EndShiftState(stage: stage);
    _flow.show(ShiftScreen.endShift);
  }

  /// "Go offline" (Shift 26, 41), "End shift" (Shift 44, 45) → 48.
  void open() => _showSheet(EndShiftStage.confirm);

  /// The shift's time is up → 46.
  void openLimit() => _showSheet(EndShiftStage.limit);

  /// Shift 46 "End shift" → 48.
  void confirm() => state = const EndShiftState(stage: EndShiftStage.confirm);

  /// Shift 46 "Keep riding", Shift 48 "Stay online", Shift 47 "Close".
  void stay() => _flow.show(null);

  /// Shift 48 "End shift" → 49 → 50, or 47 with an order on.
  Future<void> endShift() async {
    final shift = _shift;
    if (shift == null || state.stage == EndShiftStage.ending) return;
    state = const EndShiftState(stage: EndShiftStage.ending);
    final at = ref.read(clockProvider)();
    try {
      await Future<void>.delayed(AppDurations.endingShiftAtLeast);
      if (!ref.mounted) return;
      final result = await ref.read(endShiftUseCaseProvider)(_uid, shift, _status);
      if (!ref.mounted) return;
      state = result == EndShiftResult.orderInProgress
          ? const EndShiftState(stage: EndShiftStage.blocked)
          : EndShiftState(stage: EndShiftStage.confirm, endedAt: at);
    } catch (_) {
      if (!ref.mounted) return;
      // No frame for this: back on Shift 48, as it was.
      state = const EndShiftState(stage: EndShiftStage.confirm);
    }
  }

  /// Shift 47 "View order" → Order 02.
  Future<void> viewOrder() async {
    final shift = _shift;
    final status = _status;
    if (shift == null || status.queue.isEmpty) return;
    try {
      final started = await ref.read(startOrderUseCaseProvider)(_uid, shift, status);
      _flow.show(null);
      if (started == null) return;
      final order = await ref.read(watchDeliveryOrderUseCaseProvider)(started.id).first;
      if (order != null) await ref.read(startNavigationUseCaseProvider)(order);
    } catch (_) {
      // No frame for this: the screen stays as it was.
    }
  }
}

final endShiftViewModelProvider = NotifierProvider<EndShiftViewModel, EndShiftState>(EndShiftViewModel.new);
