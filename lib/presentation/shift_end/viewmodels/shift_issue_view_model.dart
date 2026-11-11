import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/shift_end.dart';
import 'end_shift_view_model.dart';
import '../../../core/constants/app_durations.dart';

/// Shift 41, 42, 54, 55: one screen by [ShiftIssue]. While location is off it
/// keeps looking, because the rider comes back from the phone's settings.
class ShiftIssueViewModel extends Notifier<ShiftIssue?> {

  Timer? _locationCheck;

  @override
  ShiftIssue? build() {
    ref.onDispose(() => _locationCheck?.cancel());
    return null;
  }

  ShiftFlowViewModel get _flow => ref.read(shiftFlowViewModelProvider.notifier);

  void show(ShiftIssue issue) {
    state = issue;
    _flow.show(ShiftScreen.shiftIssue);
    _locationCheck?.cancel();
    if (issue == ShiftIssue.locationOff) {
      _locationCheck = Timer.periodic(AppDurations.locationCheckEvery, (_) => _recheck());
    }
  }

  Future<void> _recheck() async {
    if (await ref.read(isLocationOnUseCaseProvider)()) _backToMap();
  }

  void _backToMap() {
    _locationCheck?.cancel();
    if (!ref.mounted) return;
    state = null;
    _flow.show(null);
  }

  /// Shift 41 "Open settings": back on the map as soon as location is on.
  Future<void> openSettings() async {
    await ref.read(openLocationSettingsUseCaseProvider)();
    await _recheck();
  }

  /// Shift 41 "Go offline" → 48.
  void goOffline() {
    _locationCheck?.cancel();
    ref.read(endShiftViewModelProvider.notifier).open();
  }

  /// Shift 42 "Open date settings".
  Future<void> openDateSettings() => ref.read(openDateSettingsUseCaseProvider)();

  /// Shift 42 "Check again" → 26, once the time is right.
  Future<void> checkAgain() async {
    if (await ref.read(isPhoneTimeAutomaticUseCaseProvider)()) _backToMap();
  }

  /// Shift 54 "Continue on this phone" → Shift 06.
  Future<void> continueHere() {
    _flow.home();
    return _flow.startRiding(takeOver: true);
  }

  /// Shift 54 "Cancel", Shift 55 "Try again" → Shift 05.
  void backHome() => _flow.home();
}

final shiftIssueViewModelProvider = NotifierProvider<ShiftIssueViewModel, ShiftIssue?>(ShiftIssueViewModel.new);
