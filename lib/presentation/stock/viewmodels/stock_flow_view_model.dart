import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/demo_data.dart';
import '../../auth/providers/auth_state_providers.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/app_permission.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../../domain/entities/scan_outcome.dart';
import '../../../domain/entities/stock.dart';
import '../../../core/constants/app_durations.dart';

/// The stock screens. Several Figma frames are states of one screen:
///
/// * [scan]: Stock 01, 02, 12 (toasts), 04, 10, 11 (warnings), 09 (camera off)
/// * [list]: Stock 03, 15 (all scanned), 16 (all scanned, offline)
/// * [manual]: Stock 05
/// * [saved]: Stock 13, 14 (all scanned)
/// * [lotAlert]: Stock 07, 08
///
/// Stock 06 is a shift screen: it shows once the phase is `stockLoaded`.
enum StockScreen { scan, list, manual, saved, lotAlert }

/// The toast above the bottom bar.
sealed class StockToast {
  const StockToast();
}

/// Stock 12.
class CheckingToast extends StockToast {
  const CheckingToast();
}

/// Stock 02.
class AddedToast extends StockToast {
  const AddedToast(this.name, this.loaded, this.total);

  final String name;
  final int loaded;
  final int total;
}

class StockFlowState {
  const StockFlowState({
    this.loading = true,
    this.tally,
    this.screen = StockScreen.scan,
    this.toast,
    this.warning,
    this.lotAlert,
    this.online = true,
    this.cameraOn = true,
    this.lastSyncAt,
    this.busy = false,
    this.counts = const {},
  });

  final bool loading;

  /// Load the list against the scans; null until loaded.
  final StockTally? tally;
  final StockScreen screen;
  final StockToast? toast;

  /// [ScanNotOnList], [ScanAlreadyScanned] or [ScanOverLoad] (Stock 04, 10, 11).
  final ScanOutcome? warning;

  /// [ScanLotExpired] or [ScanLotTooWarm] (Stock 07, 08).
  final ScanOutcome? lotAlert;
  final bool online;

  /// False: Stock 09.
  final bool cameraOn;

  /// "Last sync 2:14 pm".
  final DateTime? lastSyncAt;
  final bool busy;

  /// The steppers on Stock 05, by item id.
  final Map<String, int> counts;

  /// Stock 16 rather than 15.
  bool get savedOffline => !online || (tally?.waitingToSync ?? 0) > 0;

  StockFlowState copyWith({
    bool? loading,
    StockTally? tally,
    StockScreen? screen,
    StockToast? Function()? toast,
    ScanOutcome? Function()? warning,
    ScanOutcome? Function()? lotAlert,
    bool? online,
    bool? cameraOn,
    DateTime? lastSyncAt,
    bool? busy,
    Map<String, int>? counts,
  }) => StockFlowState(
    loading: loading ?? this.loading,
    tally: tally ?? this.tally,
    screen: screen ?? this.screen,
    toast: toast == null ? this.toast : toast(),
    warning: warning == null ? this.warning : warning(),
    lotAlert: lotAlert == null ? this.lotAlert : lotAlert(),
    online: online ?? this.online,
    cameraOn: cameraOn ?? this.cameraOn,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    busy: busy ?? this.busy,
    counts: counts ?? this.counts,
  );
}

/// Scanning stock onto the scooter. The rules live in the use cases; this
/// keeps which screen and state is showing, and syncs when there's signal.
class StockFlowViewModel extends Notifier<StockFlowState> {

  Timer? _toastTimer;
  StreamSubscription<bool>? _signal;
  Future<void> _syncing = Future.value();
  bool _loadStarted = false;
  bool _processing = false;

  /// Stock 13 shows once each time the signal drops; later scans use the
  /// toast until the last one (Stock 14).
  bool _offlineNoticeShown = false;
  StockScreen _beforeManual = StockScreen.scan;
  int _demoStep = 0;
  bool _demoCameraOff = false;

  @override
  StockFlowState build() {
    // Starts afresh for each rider.
    ref.watch(currentUidProvider);
    _loadStarted = false;
    _offlineNoticeShown = false;
    ref.onDispose(() {
      _toastTimer?.cancel();
      _signal?.cancel();
    });
    // Scanned stock counts from the moment the phase reaches scanning, so
    // waiting scans sync (and Home shows them) from any screen.
    ref.listen(todayShiftProvider.select((s) => s.value?.phase), (_, phase) {
      if (phase == ShiftPhase.scanning) _load();
    }, fireImmediately: true);
    // A refill is a load of its own, with its own scans.
    ref.listen(todayShiftProvider.select((s) => s.value?.stockLoadId), (previous, next) {
      if (previous == null || previous == next) return;
      _loadStarted = false;
      _demoStep = 0;
      state = const StockFlowState();
    });
    // "Continue scanning" (Shift 08) picks up where the stock stands; Refill
    // 03's "Scan stock" comes back here too. A load that failed tries again.
    ref.listen(shiftFlowViewModelProvider.select((s) => s.screen), (previous, next) {
      if (previous == next) return;
      final scanning = next == ShiftScreen.stockScan || (next == null && _shift?.phase == ShiftPhase.scanning);
      if (!scanning) return;
      if (state.tally == null) {
        state = state.copyWith(loading: true);
        _load();
      } else if (next == ShiftScreen.stockScan && !state.loading) {
        _resume();
      }
    });
    return const StockFlowState();
  }

  Shift? get _shift => ref.read(todayShiftProvider).value;
  String get _uid => ref.read(currentUidProvider)!;

  /// "View stock" on the main map: the list, after a restart too. Doesn't
  /// start scanning. Without a list to show, back to the map.
  Future<void> ensureLoaded() async {
    final shift = _shift;
    if (shift == null || state.tally != null) return;
    try {
      final local = await ref.read(loadStockUseCaseProvider)(_uid, shift.stockLoadId);
      final manifest = local.manifest;
      if (manifest != null) state = state.copyWith(tally: StockTally(manifest, local.scans));
    } catch (_) {
      if (ref.mounted && ref.read(shiftFlowViewModelProvider).screen == ShiftScreen.viewStock) {
        ref.read(shiftFlowViewModelProvider.notifier).show(null);
      }
    }
  }

  /// Fetches the load. Failing (no signal and no copy on the phone; no frame for
  /// it), back to where the scan was opened from; opening it again retries.
  Future<void> _load() async {
    final shift = _shift;
    if (shift == null || _loadStarted) return;
    _loadStarted = true;
    _signal ??= ref.read(watchSignalUseCaseProvider)().listen(_onSignal);
    final online = await ref.read(checkSignalUseCaseProvider)();
    try {
      final local = await ref.read(loadStockUseCaseProvider)(_uid, shift.stockLoadId);
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        online: online,
        tally: StockTally(local.manifest!, local.scans),
        lastSyncAt: local.lastSyncAt,
      );
      _resume();
      await _checkCamera(ask: true);
      if (online) await _sync();
    } catch (_) {
      _loadStarted = false;
      if (!ref.mounted) return;
      state = state.copyWith(loading: false);
      ref.read(shiftFlowViewModelProvider.notifier).show(shift.refill != null ? ShiftScreen.atHub : ShiftScreen.home);
    }
  }

  /// The screen for where the stock stands.
  void _resume() {
    final tally = state.tally;
    if (tally == null) return;
    final StockScreen screen;
    if (!tally.allScanned) {
      screen = StockScreen.scan;
    } else {
      screen = state.savedOffline ? StockScreen.saved : StockScreen.list;
    }
    state = state.copyWith(screen: screen, warning: () => null, lotAlert: () => null, toast: () => null);
  }

  Future<void> _reloadTally() async {
    final shift = _shift;
    final tally = state.tally;
    if (shift == null || tally == null) return;
    final local = await ref.read(loadStockScansUseCaseProvider)(_uid, shift.stockLoadId);
    if (!ref.mounted) return;
    // An open load grows with each lot scanned.
    state = state.copyWith(tally: StockTally(local.manifest ?? tally.manifest, local.scans));
  }

  /// Uploads what's waiting, one sync at a time. Failing just leaves it
  /// waiting.
  Future<void> _sync() => _syncing = _syncing.then((_) async {
    final shift = _shift;
    final tally = state.tally;
    if (shift == null || tally == null || !ref.mounted) return;
    try {
      final local = await ref.read(syncStockScansUseCaseProvider)(_uid, shift);
      if (!ref.mounted) return;
      state = state.copyWith(tally: StockTally(tally.manifest, local.scans), lastSyncAt: local.lastSyncAt);
    } catch (_) {
      // Still saved on the phone; the next change of signal tries again.
    }
  });

  Future<void> _onSignal(bool online) async {
    if (!ref.mounted) return;
    state = state.copyWith(online: online);
    if (!online) {
      _offlineNoticeShown = false;
      return;
    }
    await _sync();
    if (!ref.mounted) return;
    final tally = state.tally;
    if (tally == null || state.screen != StockScreen.saved || tally.waitingToSync > 0) return;
    if (tally.allScanned) {
      // Stock 14 → 06.
      await confirm();
    } else {
      // Stock 13: nothing left to wait for.
      state = state.copyWith(screen: StockScreen.scan);
    }
  }

  // ── Camera (Stock 09) ──

  /// With [ask], shows the system prompt when it still can.
  Future<void> _checkCamera({bool ask = false}) async {
    var result = await ref.read(checkPermissionUseCaseProvider)(AppPermission.camera);
    if (ask && result == PermissionResult.denied) {
      result = await ref.read(requestPermissionUseCaseProvider)(AppPermission.camera);
    }
    if (ref.mounted) state = state.copyWith(cameraOn: result == PermissionResult.granted && !_demoCameraOff);
  }

  /// Back from the phone's settings.
  Future<void> recheckCamera() => _checkCamera();

  /// Tapping the viewfinder on Stock 09.
  Future<void> turnOnCamera() async {
    final result = await ref.read(requestPermissionUseCaseProvider)(AppPermission.camera);
    if (result == PermissionResult.blocked) await ref.read(openPermissionSettingsUseCaseProvider)(AppPermission.camera);
    await _checkCamera();
  }

  /// The camera failed to start, or the phone has none.
  void cameraFailed() {
    if (ref.mounted && state.cameraOn) state = state.copyWith(cameraOn: false);
  }

  // ── Scanning ──

  /// A code from the camera.
  Future<void> onCode(String raw) async {
    final tally = state.tally;
    final shift = _shift;
    if (tally == null || shift == null || _processing) return;
    if (state.screen != StockScreen.scan || state.warning != null) return;
    _processing = true;
    _toastTimer?.cancel();
    state = state.copyWith(toast: () => const CheckingToast());
    try {
      final outcome = await ref.read(processScanUseCaseProvider)(_uid, shift.stockLoadId, tally, raw);
      if (!ref.mounted) return;
      switch (outcome) {
        case ScanAdded():
          await _added(outcome);
        case ScanNotOnList() || ScanAlreadyScanned() || ScanOverLoad():
          state = state.copyWith(toast: () => null, warning: () => outcome);
        case ScanLotExpired() || ScanLotTooWarm():
          state = state.copyWith(toast: () => null, lotAlert: () => outcome, screen: StockScreen.lotAlert);
      }
    } catch (_) {
      if (ref.mounted) state = state.copyWith(toast: () => null);
    } finally {
      _processing = false;
    }
  }

  Future<void> _added(ScanAdded outcome) async {
    await _reloadTally();
    if (outcome.offline) state = state.copyWith(online: false);
    if (!state.online) {
      await _afterSavingOffline(outcome);
      return;
    }
    final tally = state.tally!;
    // An open load has no last item: the rider moves on from "View list".
    if (tally.allScanned && !tally.manifest.open) {
      // Last item scanned: Stock 15, once it's synced.
      await _sync();
      if (!ref.mounted) return;
      state = state.copyWith(toast: () => null, screen: state.savedOffline ? StockScreen.saved : StockScreen.list);
      return;
    }
    _showAdded(outcome.item, tally);
    unawaited(_sync());
  }

  Future<void> _afterSavingOffline(ScanAdded outcome) async {
    final tally = state.tally!;
    if (tally.allScanned || !_offlineNoticeShown) {
      _offlineNoticeShown = true;
      state = state.copyWith(toast: () => null, screen: StockScreen.saved);
    } else {
      _showAdded(outcome.item, tally);
    }
  }

  void _showAdded(StockItem item, StockTally tally) {
    state = state.copyWith(toast: () => AddedToast(item.name, tally.portionsLoaded, tally.portions));
    _toastTimer?.cancel();
    _toastTimer = Timer(AppDurations.stockToast, () {
      if (ref.mounted && state.toast is AddedToast) state = state.copyWith(toast: () => null);
    });
  }

  /// "Scan again" (Stock 04, 10, 11).
  void scanAgain() => state = state.copyWith(warning: () => null);

  /// "Scan" (Stock 03), "Scan next item", "Keep scanning" (Stock 13), "Scan
  /// another item" (Stock 07).
  void showScanner() => state = state.copyWith(
    screen: StockScreen.scan,
    warning: () => null,
    lotAlert: () => null,
    toast: () => null,
  );

  /// "View list".
  void showList() => state = state.copyWith(screen: StockScreen.list, toast: () => null);

  /// "Manual" (Stock 01), "Enter counts instead" (Stock 09). The steppers
  /// start from what the hub packed.
  void showManual() {
    final tally = state.tally;
    if (tally == null) return;
    _beforeManual = state.screen;
    state = state.copyWith(
      screen: StockScreen.manual,
      toast: () => null,
      warning: () => null,
      counts: {for (final item in tally.manifest.items) item.id: item.quantity},
    );
  }

  void changeCount(StockItem item, int delta) {
    final tally = state.tally;
    if (tally == null) return;
    final next = ((state.counts[item.id] ?? 0) + delta).clamp(tally.count(item.id), item.quantity);
    state = state.copyWith(counts: {...state.counts, item.id: next});
  }

  /// "Save counts" (Stock 05): complete counts go straight to Stock 06 (or
  /// Stock 14 without signal); otherwise on with the rest.
  Future<void> saveCounts() async {
    final tally = state.tally;
    final shift = _shift;
    if (tally == null || shift == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await ref.read(saveManualCountsUseCaseProvider)(_uid, shift.stockLoadId, tally, state.counts);
      await _reloadTally();
      final online = await ref.read(checkSignalUseCaseProvider)();
      if (online) await _sync();
      if (!ref.mounted) return;
      state = state.copyWith(online: online);
      final updated = state.tally!;
      if (updated.allScanned && !state.savedOffline) {
        await _confirm();
      } else if (state.savedOffline) {
        _offlineNoticeShown = true;
        state = state.copyWith(screen: StockScreen.saved);
      } else {
        state = state.copyWith(screen: StockScreen.list);
      }
    } catch (_) {
      // No frame for this: the screen stays as it was.
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// "Move to quarantine" (Stock 08).
  Future<void> moveToQuarantine() async {
    final alert = state.lotAlert;
    final shift = _shift;
    if (alert is! ScanLotTooWarm || shift == null) return;
    await ref.read(moveLotToQuarantineUseCaseProvider)(_uid, shift.stockLoadId, alert.lot);
    if (!ref.mounted) return;
    showScanner();
    if (state.online) unawaited(_sync());
  }

  /// "Confirm stock" (Stock 15 → 06): the phase change shows Stock 06.
  Future<void> confirm() async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await _confirm();
    } catch (_) {
      // No frame for this: the screen stays as it was.
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> _confirm() async {
    final tally = state.tally;
    final shift = _shift;
    if (tally == null || shift == null) return;
    await ref.read(confirmStockUseCaseProvider)(_uid, shift, tally);
  }

  /// The back arrow and the system back gesture (flow map 7, 8b).
  void back() {
    final tally = state.tally;
    switch (state.screen) {
      case StockScreen.manual:
        state = state.copyWith(screen: _beforeManual);
      case StockScreen.lotAlert:
        showScanner();
      case StockScreen.list when tally != null && tally.allScanned && state.savedOffline:
        // Stock 16 → 14.
        state = state.copyWith(screen: StockScreen.saved);
      case StockScreen.saved when tally != null && !tally.allScanned:
        // Stock 13.
        showScanner();
      case StockScreen.scan || StockScreen.list || StockScreen.saved:
        // A refill goes back to what's being collected (Refill 03).
        ref
            .read(shiftFlowViewModelProvider.notifier)
            .show(_shift?.refill != null ? ShiftScreen.atHub : ShiftScreen.home);
    }
  }

  // ── Demo only ──

  /// Tapping the viewfinder: the next sample code.
  Future<void> demoNextScan(List<String> script) async {
    if (_processing || state.warning != null) return;
    // A refill just scans its load, so a different load can't get stuck.
    final refill = _shift?.refill != null;
    final items = state.tally?.manifest.items ?? const <StockItem>[];
    final codes = refill
        ? [
            for (final item in items)
              for (var n = 1; n <= item.quantity; n++) ScanCode(itemId: item.id, lotId: DemoData.goodLot, portion: '$n').raw,
          ]
        : script;
    if (codes.isEmpty) return;
    await onCode(codes[_demoStep++ % codes.length]);
  }

  /// The demo's "Camera" pill.
  Future<void> demoSetCameraOff(bool off) async {
    _demoCameraOff = off;
    if (off) {
      state = state.copyWith(cameraOn: false);
    } else {
      await _checkCamera(ask: true);
    }
  }
}

final stockFlowViewModelProvider = NotifierProvider<StockFlowViewModel, StockFlowState>(StockFlowViewModel.new);
