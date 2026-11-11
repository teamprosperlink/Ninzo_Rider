import '../../../core/constants/app_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../../domain/entities/online_status.dart';
import '../../online/providers/online_providers.dart';
import '../../../domain/usecases/refill_usecases.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/shift_end.dart';
import '../../shift_end/viewmodels/shift_issue_view_model.dart';
import '../../../domain/entities/home_status.dart';
import '../../../domain/entities/shift.dart';
import '../../../domain/usecases/shift_flow_usecases.dart';
import '../providers/shift_providers.dart';

/// The rider's day screens. Several Figma frames are states of one screen:
///
/// * [home]: Shift 01–09 ([HomeStatus])
/// * [checklist]: Shift 10–12 (none, some, all ticked)
/// * [hubMap]: Shift 52 heading to hub
/// * [hubStatus]: Shift 53 at hub, hub is packing
/// * [stockEmpty]: Shift 51 (Go online without stock)
/// * [atHub]: at the hub with the stock packed, morning or refill (Refill 03)
/// * [stockScan]: scanning the stock (Stock 01–05, 07–16, see StockFlowPage)
/// * [stockConfirmed]: Stock 06, right after confirming
/// * [chooseSpot]: Shift 13–18, see ChooseSpotPage
/// * [goOnline]: heading to the spot (Shift 19–24, see GoOnlinePage)
/// * [online]: the main map (Shift 25–32, 35, see OnlineMapPage)
/// * [addTime]: Shift 33, 34
/// * [viewStock]: "View stock", the stock list without its actions
/// * [takeBreak]: Shift 43
/// * [onBreak]: Shift 44, 45, see OnBreakPage
/// * [refillAlert]: Refill 01, 02, see RefillAlertPage
/// * [refilled]: Refill 04
/// * [restock]: Restock 01–05, see RestockPage
/// * [endShift]: Shift 46–49, see EndShiftPage
/// * [shiftSummary]: Shift 50
/// * [shiftIssue]: Shift 41, 42, 54, 55, see ShiftIssuePage
/// * [earnings]: Earnings 01
/// * [syncStatus]: Sync 01
/// * [profile]: Profile 01, 03, see ProfileMenuPage
/// * [profileHelp]: Profile 02, 09, see HelpCentrePage
/// * [profileSpot], [profileNotifications], [profileShifts], [profileDetails],
///   [profileDocuments]: Profile 04, 05, 06, 07, 08
///
/// A started order takes over from all of these (see OrderFlowPage).
enum ShiftScreen {
  home,
  checklist,
  hubMap,
  hubStatus,
  stockEmpty,
  atHub,
  stockScan,
  stockConfirmed,
  chooseSpot,
  goOnline,
  online,
  addTime,
  viewStock,
  takeBreak,
  onBreak,
  endShift,
  refillAlert,
  refilled,
  restock,
  shiftSummary,
  shiftIssue,
  earnings,
  syncStatus,
  profile,
  profileHelp,
  profileSpot,
  profileNotifications,
  profileShifts,
  profileDetails,
  profileDocuments,
}

class ShiftFlowState {
  const ShiftFlowState({this.screen, this.starting = false, this.busy = false, this.stayedOnline = false});

  /// Screen the rider moved to; null shows the one for the phase.
  final ShiftScreen? screen;

  /// "Start riding" in progress (Shift 06).
  final bool starting;
  final bool busy;

  /// "Stay online" on Refill 01: no asking again until the next refill.
  final bool stayedOnline;

  ShiftFlowState copyWith({
    ShiftScreen? Function()? screen,
    bool? starting,
    bool? busy,
    bool? stayedOnline,
  }) =>
      ShiftFlowState(
        screen: screen == null ? this.screen : screen(),
        starting: starting ?? this.starting,
        busy: busy ?? this.busy,
        stayedOnline: stayedOnline ?? this.stayedOnline,
      );
}

/// Moves the rider through Home, the checklist and the hub trip. The phase
/// lives on the shift (so it survives restarts); this keeps which screen is
/// on top and the commands in progress.
class ShiftFlowViewModel extends Notifier<ShiftFlowState> {
  ShiftScreen? _beforeProfile;

  @override
  ShiftFlowState build() {
    // Starts afresh for each rider.
    ref.watch(currentUidProvider);
    // A new phase shows its own screen (e.g. arriving at the hub).
    ref.listen(todayShiftProvider.select((s) => s.value?.phase), (previous, next) {
      if (previous == next) return;
      // Confirming the stock shows Stock 06 before Home's Shift 09.
      final confirmed = previous == ShiftPhase.scanning && next == ShiftPhase.stockLoaded;
      final refilled = _shift?.refill != null;
      state = state.copyWith(
        screen: () => confirmed && !refilled ? ShiftScreen.stockConfirmed : null,
      );
    });
    // A refill's new stock asks again; moving spot doesn't.
    ref.listen(todayShiftProvider.select((s) => s.value?.stockLoadId), (previous, next) {
      if (previous != next) state = state.copyWith(stayedOnline: false);
    });
    // A restock moving on shows again after the rider left it for the map.
    ref.listen(onlineStatusProvider.select((s) => s.value?.restock?.stage), (previous, next) {
      if (previous != next && state.screen == ShiftScreen.online) state = state.copyWith(screen: () => null);
    });
    return const ShiftFlowState();
  }

  Shift? get _shift => ref.read(todayShiftProvider).value;
  String get _uid => ref.read(currentUidProvider)!;

  /// The screen to show for [shift].
  ShiftScreen screenFor(Shift shift, [OnlineStatus status = const OnlineStatus()]) =>
      state.screen ??
      switch (shift.phase) {
        ShiftPhase.notStarted => ShiftScreen.home,
        // A refill's own Stock 06 is Refill 04.
        ShiftPhase.stockLoaded => shift.refill != null ? ShiftScreen.refilled : ShiftScreen.home,
        ShiftPhase.checklist => ShiftScreen.checklist,
        ShiftPhase.headingToHub => ShiftScreen.hubMap,
        ShiftPhase.atHub =>
          shift.stockRequest == StockRequestStatus.ready ? ShiftScreen.atHub : ShiftScreen.hubStatus,
        ShiftPhase.scanning => ShiftScreen.stockScan,
        ShiftPhase.headingToSpot => ShiftScreen.goOnline,
        ShiftPhase.online =>
          status.breakState != null
              ? ShiftScreen.onBreak
              // An offer expires in 30 s on the rider API: it comes before a restock.
              : status.restock != null && !(kRiderApi && status.queue.isNotEmpty)
              ? ShiftScreen.restock
              : refillPromptOf(shift, status, stayedOnline: state.stayedOnline) != RefillPrompt.none
              ? ShiftScreen.refillAlert
              : ShiftScreen.online,
        ShiftPhase.ended => ShiftScreen.shiftSummary,
      };

  HomeStatus homeStatus(Shift shift, DateTime now) =>
      ref.read(homeStatusOfUseCaseProvider)(shift, now, starting: state.starting);

  Future<void> _run(Future<void> Function(Shift shift) command) async {
    final shift = _shift;
    if (shift == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await command(shift);
    } catch (_) {
      // No frame for this: the screen stays as it was.
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// "Stay online" (Refill 01) → the map.
  void stayOnline() => state = state.copyWith(stayedOnline: true);

  /// Back to Home from any screen (the phase stays).
  void home() => state = state.copyWith(screen: () => ShiftScreen.home);

  /// To [screen]; null is the phase's own.
  void show(ShiftScreen? screen) => state = state.copyWith(screen: () => screen);

  /// The avatar → Profile 01.
  void openProfile() {
    _beforeProfile = state.screen;
    show(ShiftScreen.profile);
  }

  /// Back from Profile 01, to where it was opened from.
  void closeProfile() {
    show(_beforeProfile);
    _beforeProfile = null;
  }

  /// Shift 01, 02, 51 "Ask hub to prepare" / "Request hub to prepare".
  Future<void> askHubToPrepare() => _run((shift) async {
    await ref.read(replyToStockRequestUseCaseProvider)(_uid, shift, coming: true);
    state = state.copyWith(screen: () => ShiftScreen.home);
  });

  /// Shift 04, 05 "Start riding" → 06 → 10, or 54, 55; with [takeOver], Shift
  /// 54's "Continue on this phone".
  Future<void> startRiding({bool takeOver = false}) async {
    final shift = _shift;
    if (shift == null || state.starting) return;
    state = state.copyWith(starting: true);
    try {
      final opened = await ref.read(openShiftUseCaseProvider)(_uid, shift.id, takeOver: takeOver);
      if (opened != OpenShiftResult.opened) {
        ref
            .read(shiftIssueViewModelProvider.notifier)
            .show(opened == OpenShiftResult.noInternet ? ShiftIssue.noInternet : ShiftIssue.shiftAlreadyOpen);
        return;
      }
      await ref.read(startShiftUseCaseProvider)(_uid, shift);
    } catch (_) {
      // No frame for this: the screen stays as it was.
    } finally {
      if (ref.mounted) state = state.copyWith(starting: false);
    }
  }

  /// Shift 07 "Go to hub", Shift 51 "Navigate to Hub 2".
  void goToHub() {
    final shift = _shift;
    if (shift == null) return;
    state = state.copyWith(
      screen: () => switch (shift.phase) {
        ShiftPhase.headingToHub => ShiftScreen.hubMap,
        ShiftPhase.atHub => null,
        // Not left for the hub yet: start the day first.
        _ => ShiftScreen.home,
      },
    );
  }

  /// Shift 07, 09 "Go online". Without stock: Shift 51.
  Future<void> goOnline() => _run((shift) async {
    final result = await ref.read(goOnlineUseCaseProvider)(_uid, shift);
    switch (result) {
      case GoOnlineResult.needsStock:
        state = state.copyWith(screen: () => ShiftScreen.stockEmpty);
      case GoOnlineResult.headToSpot:
        state = state.copyWith(screen: () => ShiftScreen.goOnline);
      // No frame for this: the screen stays as it was.
      case GoOnlineResult.noSignal:
        break;
    }
  });

  /// Shift 08 "Continue scanning".
  void continueScanning() => state = state.copyWith(screen: () => ShiftScreen.stockScan);

  /// Refill 03 "Scan stock" → Stock 01.
  Future<void> startScanning() => _run((shift) async {
    await ref.read(startScanningUseCaseProvider)(_uid, shift);
    // Back here from scanning the phase doesn't change.
    if (ref.mounted) state = state.copyWith(screen: () => null);
  });
}

final shiftFlowViewModelProvider = NotifierProvider<ShiftFlowViewModel, ShiftFlowState>(ShiftFlowViewModel.new);
