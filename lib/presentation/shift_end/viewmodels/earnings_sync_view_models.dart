import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../../domain/entities/online_status.dart';
import '../../online/providers/online_providers.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/shift_end.dart';
import '../../../domain/usecases/shift_end_usecases.dart';

/// Earnings 01.
class EarningsViewModel extends Notifier<(EarningsBreakdown, int)> {
  @override
  (EarningsBreakdown, int) build() {
    final status = ref.watch(onlineStatusProvider).value ?? const OnlineStatus();
    return (earningsOf(status), status.orders);
  }

  /// "Back to waiting" and back → Shift 26.
  void back() => ref.read(shiftFlowViewModelProvider.notifier).show(null);
}

final earningsViewModelProvider = NotifierProvider<EarningsViewModel, (EarningsBreakdown, int)>(EarningsViewModel.new);

/// What Sync 01 shows.
class SyncStatusState {
  const SyncStatusState({this.snapshot = const SyncSnapshot(), this.online = true, this.busy = false});

  final SyncSnapshot snapshot;
  final bool online;
  final bool busy;
}

/// Sync 01: fresh each time it opens, and when the signal changes.
class SyncStatusViewModel extends Notifier<SyncStatusState> {
  StreamSubscription<bool>? _signal;

  @override
  SyncStatusState build() {
    _signal = ref.watch(watchSignalUseCaseProvider)().listen((_) => _load());
    ref.onDispose(() => _signal?.cancel());
    Future.microtask(_load);
    return const SyncStatusState();
  }

  Future<void> _load() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final snapshot = await ref.read(loadSyncStatusUseCaseProvider)(uid);
    final online = await ref.read(checkSignalUseCaseProvider)();
    if (ref.mounted) state = SyncStatusState(snapshot: snapshot, online: online, busy: state.busy);
  }

  /// "Try again now" → Shift 26: what can't go yet keeps waiting.
  Future<void> tryAgain() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null || state.busy) return;
    state = SyncStatusState(snapshot: state.snapshot, online: state.online, busy: true);
    try {
      await ref.read(retrySyncUseCaseProvider)(uid);
    } finally {
      if (ref.mounted) state = SyncStatusState(snapshot: state.snapshot, online: state.online);
    }
    back();
  }

  /// Back → Shift 26.
  void back() {
    if (ref.mounted) ref.read(shiftFlowViewModelProvider.notifier).show(null);
  }
}

final syncStatusViewModelProvider = NotifierProvider.autoDispose<SyncStatusViewModel, SyncStatusState>(
  SyncStatusViewModel.new,
);
