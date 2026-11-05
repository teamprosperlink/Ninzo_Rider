import '../../../orders/domain/repositories/handover_repository.dart';
import '../../../orders/domain/usecases/handover_usecases.dart';
import '../../../stock/data/repositories/signal_repositories.dart';
import '../../domain/entities/shift_end.dart';
import '../../domain/repositories/shift_end_repositories.dart';

/// What the phone holds back for signal: saved handovers and their arrivals.
class LocalSyncStatusRepository implements SyncStatusRepository {
  LocalSyncStatusRepository(this._store, this._sync);

  final HandoverStore _store;
  final SyncSavedHandovers _sync;

  @override
  Future<SyncSnapshot> load(String uid) async {
    final local = await _store.load(uid);
    final events = <SyncEvent>[
      for (final saved in local.saved) ...[
        if (saved.gateConfirmedAt case final at?) SyncEvent(label: 'Arrival · ${saved.gateName}', at: at),
        SyncEvent(label: 'Handover · #${saved.number}', at: saved.savedAt),
      ],
    ]..sort((a, b) => a.at.compareTo(b.at));
    return SyncSnapshot(events: events, lastSync: local.lastSync, deliveries: local.saved.length);
  }

  @override
  Future<void> retry(String uid) => _sync(uid);
}

/// The local queue, or the design's sample while the demo pill plays one.
class DemoSyncStatusRepository implements SyncStatusRepository {
  DemoSyncStatusRepository(this._local, this._signal);

  final SyncStatusRepository _local;
  final DemoSignalRepository? _signal;

  SyncSnapshot? sample;

  @override
  Future<SyncSnapshot> load(String uid) async => sample ?? await _local.load(uid);

  /// In the demo, trying again finds the signal back.
  @override
  Future<void> retry(String uid) async {
    sample = null;
    _signal?.online = true;
    await _local.retry(uid);
  }
}
