import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/pre_shift_check.dart';
import '../providers/shift_providers.dart';

class ChecklistState {
  const ChecklistState({this.ticked = const {}, this.checking, this.busy = false});

  final Set<PreShiftCheck> ticked;

  /// Item whose device check is running.
  final PreShiftCheck? checking;

  /// "Go to hub" in progress.
  final bool busy;


  bool get allTicked => ticked.containsAll(PreShiftCheck.values);
}

/// "Before you start" (Shift 10–12). Manual items toggle; phone battery and
/// location are checked on the phone, and the scooter's charge against its
/// telemetry, before they tick.
class ChecklistViewModel extends Notifier<ChecklistState> {
  @override
  ChecklistState build() => const ChecklistState();

  Future<void> toggle(PreShiftCheck check) async {
    if (state.checking != null || state.busy) return;
    if (state.ticked.contains(check)) {
      state = ChecklistState(ticked: {...state.ticked}..remove(check));
      return;
    }
    final shift = ref.read(todayShiftProvider).value;
    if (shift == null) return;
    state = ChecklistState(ticked: state.ticked, checking: check);
    final problem = await ref.read(checkPreShiftItemUseCaseProvider)(check, shift);
    if (!ref.mounted) return;
    // Refused (no frame says why): the item stays unticked.
    state = ChecklistState(ticked: problem == null ? {...state.ticked, check} : state.ticked);
  }

  /// Shift 12 "Go to hub" → Shift 52.
  Future<void> goToHub() async {
    final shift = ref.read(todayShiftProvider).value;
    if (shift == null || state.busy) return;
    state = ChecklistState(ticked: state.ticked, busy: true);
    try {
      await ref.read(finishChecklistUseCaseProvider)(ref.read(currentUidProvider)!, shift, state.ticked);
    } catch (_) {
      // No frame for this: the screen stays as it was.
    }
    if (ref.mounted) state = ChecklistState(ticked: state.ticked);
  }
}

final checklistViewModelProvider = NotifierProvider.autoDispose<ChecklistViewModel, ChecklistState>(
  ChecklistViewModel.new,
);
