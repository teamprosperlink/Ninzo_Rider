import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/clock_provider.dart';
import '../../auth/providers/auth_state_providers.dart';
import '../../refill/viewmodels/refill_view_model.dart';
import '../../../injection_container.dart';
import '../../shift_end/viewmodels/end_shift_view_model.dart';
import '../../shift_end/viewmodels/shift_issue_view_model.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../stock/viewmodels/stock_flow_view_model.dart';
import '../../../domain/entities/online_status.dart';
import '../../../domain/usecases/online_usecases.dart';
import '../../../domain/usecases/spot_usecases.dart';
import '../providers/online_providers.dart';
import '../../../core/constants/app_durations.dart';

class OnlineMapState {
  const OnlineMapState({
    this.metersFromSpot,
    this.option = AddTimeOption.min30,
    this.adding = false,
    this.timeAddedEnd,
    this.endingDismissedFor,
    this.busy = false,
    this.offline = false,
    this.waitingToSync = 0,
  });

  /// From the live position; null until known.
  final double? metersFromSpot;

  /// Shift 33's choice.
  final AddTimeOption option;

  /// Shift 34.
  final bool adding;

  /// Shift 35, for a few seconds.
  final DateTime? timeAddedEnd;

  /// "Let my shift end" for this end: no more asking.
  final DateTime? endingDismissedFor;

  final bool busy;

  /// No signal (Shift 40).
  final bool offline;

  /// Deliveries saved on the phone (Shift 40).
  final int waitingToSync;

  OnlineMapState copyWith({
    double? Function()? metersFromSpot,
    AddTimeOption? option,
    bool? adding,
    DateTime? Function()? timeAddedEnd,
    DateTime? endingDismissedFor,
    bool? busy,
    bool? offline,
    int? waitingToSync,
  }) => OnlineMapState(
    metersFromSpot: metersFromSpot == null ? this.metersFromSpot : metersFromSpot(),
    option: option ?? this.option,
    adding: adding ?? this.adding,
    timeAddedEnd: timeAddedEnd == null ? this.timeAddedEnd : timeAddedEnd(),
    endingDismissedFor: endingDismissedFor ?? this.endingDismissedFor,
    busy: busy ?? this.busy,
    offline: offline ?? this.offline,
    waitingToSync: waitingToSync ?? this.waitingToSync,
  );
}

/// The main map (Shift 25–35): follows the rider while online, picks the
/// sheet and the banner through the use cases, and moves to where the buttons
/// lead.
class OnlineMapViewModel extends Notifier<OnlineMapState> {

  StreamSubscription<LatLng>? _sub;
  StreamSubscription<bool>? _signal;
  Timer? _timeAdded;
  Timer? _endCheck;
  DateTime? _endRoutedFor;

  @override
  OnlineMapState build() {
    // Starts afresh for each rider.
    ref.watch(currentUidProvider);
    ref.onDispose(_stop);
    ref.onDispose(() => _timeAdded?.cancel());
    // Keeps the status live on the screens around the map (Add time, View
    // stock): a provider nobody listens to is paused.
    ref.listen(onlineStatusProvider, (_, _) {});
    ref.listen(todayShiftProvider.select((s) => s.value?.phase), (_, phase) {
      if (phase == ShiftPhase.online) {
        _start();
      } else {
        _stop();
      }
    }, fireImmediately: true);
    return const OnlineMapState();
  }

  Shift? get _shift => ref.read(todayShiftProvider).value;
  OnlineStatus get _status => ref.read(onlineStatusProvider).value ?? const OnlineStatus();
  String get _uid => ref.read(currentUidProvider)!;
  ShiftFlowViewModel get _flow => ref.read(shiftFlowViewModelProvider.notifier);

  void _start() {
    _sub ??= ref.read(watchRiderPositionUseCaseProvider)().listen(_onPosition, onError: (Object _) {});
    _endCheck ??= Timer.periodic(AppDurations.shiftEndCheckEvery, (_) {
      checkShiftEnded();
      checkDevice();
    });
    if (_signal == null) {
      _signal = ref.read(watchSignalUseCaseProvider)().listen(_onSignal);
      ref.read(checkSignalUseCaseProvider)().then(_onSignal);
      checkDevice();
    }
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _endCheck?.cancel();
    _endCheck = null;
    _signal?.cancel();
    _signal = null;
  }

  /// Shift 40 comes and goes with the signal.
  Future<void> _onSignal(bool online) async {
    if (!ref.mounted) return;
    state = state.copyWith(offline: !online);
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final waiting = (await ref.read(loadSyncStatusUseCaseProvider)(uid)).deliveries;
    if (ref.mounted) state = state.copyWith(waitingToSync: waiting);
  }

  /// Location off or a wrong phone time stop the rider on the map (Shift 41,
  /// 42); orders, breaks and other screens finish first.
  Future<void> checkDevice() async {
    bool onMap() {
      final shift = _shift;
      return ref.mounted && shift != null && _flow.screenFor(shift, _status) == ShiftScreen.online;
    }

    if (!onMap() || _status.queue.isNotEmpty) return;
    final issue = await ref.read(checkDeviceHealthUseCaseProvider)();
    if (issue != null && onMap()) ref.read(shiftIssueViewModelProvider.notifier).show(issue);
  }

  void _onPosition(LatLng position) {
    final shift = _shift;
    if (shift == null) return;
    state = state.copyWith(metersFromSpot: () => SpotRules.metersBetween(position, shift.spot.point));
  }

  /// The shift's time is up, with no action on the banner: Shift 46.
  void checkShiftEnded() {
    final shift = _shift;
    if (shift == null || shift.phase != ShiftPhase.online || _status.queue.isNotEmpty) return;
    final end = shiftEndOf(shift, _status);
    if (ref.read(clockProvider)().isBefore(end) || end == _endRoutedFor) return;
    _endRoutedFor = end;
    ref.read(endShiftViewModelProvider.notifier).openLimit();
  }

  OnlineAlert? alert(Shift shift, OnlineStatus status, DateTime now) => ref.read(selectOnlineAlertUseCaseProvider)(
    shift: shift,
    status: status,
    now: now,
    metersFromSpot: state.metersFromSpot,
    timeAddedEnd: state.timeAddedEnd,
    endingDismissedFor: state.endingDismissedFor,
    offline: state.offline,
    waitingToSync: state.waitingToSync,
  );

  OnlineMode mode(OnlineStatus status) =>
      onlineModeOf(status, metersFromSpot: state.metersFromSpot, justConfirmed: ref.read(spotJustConfirmedProvider));

  /// Shift 30 "Navigate to spot" → 21.
  Future<void> navigateToSpot() async {
    final shift = _shift;
    if (shift == null) return;
    await ref.read(returnToSpotUseCaseProvider)(_uid, shift);
  }

  /// Shift 32 "Keep riding" → 33.
  void keepRiding() {
    state = state.copyWith(option: AddTimeOption.min30);
    _flow.show(ShiftScreen.addTime);
  }

  void selectOption(AddTimeOption option) => state = state.copyWith(option: option);

  /// Shift 33 "Keep riding · 30 min" → 34 → 35.
  Future<void> addTime() async {
    final shift = _shift;
    if (shift == null || state.adding) return;
    state = state.copyWith(adding: true);
    try {
      final end = await ref.read(addShiftTimeUseCaseProvider)(_uid, shift, _status, state.option);
      if (!ref.mounted) return;
      state = state.copyWith(adding: false, timeAddedEnd: () => end);
      _flow.show(null);
      _timeAdded?.cancel();
      _timeAdded = Timer(AppDurations.timeAddedHold, dismissTimeAdded);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(adding: false);
    }
  }

  /// Shift 35 → 26.
  void dismissTimeAdded() {
    _timeAdded?.cancel();
    state = state.copyWith(timeAddedEnd: () => null);
  }

  /// Shift 33 "Let my shift end": back to the map, the shift ends on time.
  void letShiftEnd() {
    final shift = _shift;
    if (shift != null) state = state.copyWith(endingDismissedFor: shiftEndOf(shift, _status));
    _flow.show(null);
  }

  /// Shift 28 "Start order" → Order 01: the order then takes over the screen.
  Future<void> startOrder() async {
    final shift = _shift;
    if (shift == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await ref.read(startOrderUseCaseProvider)(_uid, shift, _status);
      if (ref.mounted) state = state.copyWith(busy: false);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  void viewStock() {
    ref.read(stockFlowViewModelProvider.notifier).ensureLoaded();
    _flow.show(ShiftScreen.viewStock);
  }

  void takeBreak() => _flow.show(ShiftScreen.takeBreak);

  /// Shift 26 "Go offline" → 48.
  void goOffline() => ref.read(endShiftViewModelProvider.notifier).open();

  /// Shift 29's "Request hub to prepare" → Refill 03.
  Future<void> requestRefill() => ref.read(refillViewModelProvider.notifier).goRefill();

  /// Shift 36 "Navigate to spot" → 37.
  Future<void> acceptNudge() async {
    final shift = _shift;
    final nudge = _status.nudge;
    if (shift == null || nudge == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      ref.read(demoRiderLocationProvider)?.changeSpot(nudge.spot.point, nudge.meters.toDouble());
      await ref.read(answerRelocationUseCaseProvider).accept(_uid, shift, nudge);
      if (ref.mounted) state = state.copyWith(busy: false);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// Shift 36 "Not now", Shift 39 "Got it" → 26.
  Future<void> dismissNudge() async {
    final shift = _shift;
    if (shift == null) return;
    try {
      await ref.read(answerRelocationUseCaseProvider).dismiss(_uid, shift.id);
    } catch (_) {
      // No frame for this: the screen stays as it was.
    }
  }
}

final onlineMapViewModelProvider = NotifierProvider<OnlineMapViewModel, OnlineMapState>(OnlineMapViewModel.new);
