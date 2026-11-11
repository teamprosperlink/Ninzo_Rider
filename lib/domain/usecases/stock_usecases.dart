import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../entities/shift.dart';
import 'shift_flow_usecases.dart';
import '../entities/scan_outcome.dart';
import '../entities/stock.dart';
import '../repositories/stock_repository.dart';
import '../../core/constants/app_patterns.dart';

/// A backend call that takes longer than this counts as no signal.
const stockCallTimeout = Duration(seconds: 8);

/// Opens the shift's stock: the load from the backend, or the phone's copy
/// without signal, with this phone's scans and any already uploaded.
class LoadStock {
  const LoadStock(this._repository, this._store);

  final StockRepository _repository;
  final StockScanStore _store;

  Future<StockLocalState> call(String uid, String shiftId) async {
    var local = await _store.load(uid, shiftId);
    try {
      final manifest = await _repository.manifest(uid, shiftId).timeout(stockCallTimeout);
      final uploaded = await _repository.uploadedScans(uid, shiftId).timeout(stockCallTimeout);
      final known = {for (final s in local.scans) s.code};
      local = local.copyWith(
        manifest: manifest,
        scans: [...local.scans, ...uploaded.where((s) => !known.contains(s.code))],
      );
      await _store.save(uid, shiftId, local);
    } catch (_) {
      if (local.manifest == null) {
        throw const AppException();
      }
    }
    return local;
  }
}

/// The rules for one scanned code. Saves it on the phone when it counts.
///
/// With [_lots] (the rider API) the code is a lot's: the backend loads the
/// whole lot and says what it is, so it needs signal.
class ProcessScan {
  const ProcessScan(this._repository, this._store, this._signal, this._clock, [this._lots]);

  final StockRepository _repository;
  final StockScanStore _store;
  final SignalRepository _signal;
  final DateTime Function() _clock;
  final LotScanRepository? _lots;

  Future<ScanOutcome> call(String uid, String shiftId, StockTally tally, String raw) async {
    final lots = _lots;
    if (lots != null) return _scanLot(lots, uid, shiftId, tally, raw.trim());
    final code = ScanCode.parse(raw);
    final item = code == null ? null : tally.manifest.item(code.itemId);
    if (code == null || item == null) return const ScanNotOnList();
    if (tally.hasCode(raw)) return ScanAlreadyScanned(item);
    if (tally.count(item.id) >= item.quantity) return ScanOverLoad(item);

    // The freshest word on the lot; without signal, the phone's copy.
    var lot = tally.manifest.lots[code.lotId];
    var offline = !await _signal.isOnline();
    if (!offline) {
      try {
        lot = await _repository.lot(uid, shiftId, code.lotId).timeout(stockCallTimeout) ?? lot;
      } catch (_) {
        offline = true;
      }
    }
    final now = _clock();
    if (lot != null && lot.isExpired(now)) return ScanLotExpired(item, lot, now);
    if (lot != null && lot.isTooWarm) return ScanLotTooWarm(item, lot);

    final local = await _store.load(uid, shiftId);
    await _store.save(
      uid,
      shiftId,
      local.copyWith(
        scans: [
          ...local.scans,
          StockScan(code: raw, itemId: item.id, lotId: code.lotId, at: now),
        ],
      ),
    );
    return ScanAdded(item, offline: offline);
  }

  Future<ScanOutcome> _scanLot(LotScanRepository lots, String uid, String shiftId, StockTally tally, String code) async {
    if (code.isEmpty) return const ScanNotOnList();
    if (!await _signal.isOnline()) throw const AppException();
    final now = _clock();
    final result = await lots.scanLot(uid, shiftId, code, now).timeout(stockCallTimeout);
    final manifest = result.manifest;
    if (manifest != null) {
      final local = await _store.load(uid, shiftId);
      final fresh = {for (final s in result.scans) s.code};
      await _store.save(
        uid,
        shiftId,
        local.copyWith(
          manifest: manifest,
          scans: [...local.scans.where((s) => !fresh.contains(s.code)), ...result.scans],
          lastSyncAt: now,
        ),
      );
    }
    final item = result.item ?? const StockItem(id: '', name: '', quantity: 0);
    final lot = result.lot ?? StockLot(id: code, itemId: item.id);
    return switch (result.status) {
      LotScanStatus.loaded => ScanAdded(item),
      LotScanStatus.tooWarm => ScanLotTooWarm(item, lot),
      LotScanStatus.expired => ScanLotExpired(item, lot, now),
      LotScanStatus.alreadyLoaded => ScanAlreadyScanned(item),
      LotScanStatus.notOnList => const ScanNotOnList(),
    };
  }
}

/// "Save counts" (Stock 05): portions counted by hand, for QR codes that
/// won't scan. Counts stay between what's already scanned and what's packed.
class SaveManualCounts {
  const SaveManualCounts(this._store, this._clock);

  final StockScanStore _store;
  final DateTime Function() _clock;

  Future<void> call(String uid, String shiftId, StockTally tally, Map<String, int> counts) async {
    final now = _clock();
    final added = <StockScan>[
      for (final item in tally.manifest.items)
        for (var n = tally.count(item.id); n < (counts[item.id] ?? 0).clamp(0, item.quantity); n++)
          StockScan(code: AppPatterns.manualScan(item.id, n + 1), itemId: item.id, method: ScanMethod.manual, at: now),
    ];
    if (added.isEmpty) return;
    final local = await _store.load(uid, shiftId);
    await _store.save(uid, shiftId, local.copyWith(scans: [...local.scans, ...added]));
  }
}

/// "Move to quarantine" (Stock 08): saved like a scan, sent when there's signal.
class MoveLotToQuarantine {
  const MoveLotToQuarantine(this._store, this._clock);

  final StockScanStore _store;
  final DateTime Function() _clock;

  Future<void> call(String uid, String shiftId, StockLot lot) async {
    final local = await _store.load(uid, shiftId);
    if (local.quarantine.any((q) => q.lotId == lot.id)) return;
    await _store.save(
      uid,
      shiftId,
      local.copyWith(
        quarantine: [
          ...local.quarantine,
          QuarantineRequest(lotId: lot.id, itemId: lot.itemId, at: _clock()),
        ],
      ),
    );
  }
}

/// Uploads everything saved on the phone and updates the shift's scanned
/// count. Throws while there is no signal; what wasn't sent stays saved.
class SyncStockScans {
  const SyncStockScans(this._repository, this._store, this._record, this._clock);

  final StockRepository _repository;
  final StockScanStore _store;
  final RecordStockScans _record;
  final DateTime Function() _clock;

  Future<StockLocalState> call(String uid, Shift shift) async {
    final loadId = shift.stockLoadId;
    final local = await _store.load(uid, loadId);
    final pending = local.scans.where((s) => !s.synced).toList();
    final counted = local.scans.length;
    final recorded = shift.refill != null || shift.stock.scanned == counted;
    if (pending.isEmpty && local.quarantine.isEmpty && recorded) return local;

    if (pending.isNotEmpty) await _repository.uploadScans(uid, loadId, pending).timeout(stockCallTimeout);
    for (final request in local.quarantine) {
      await _repository.moveToQuarantine(uid, loadId, request).timeout(stockCallTimeout);
    }
    await _record(uid, shift, counted).timeout(stockCallTimeout);

    // Scans may have been added meanwhile.
    final latest = await _store.load(uid, loadId);
    final sent = {for (final s in pending) s.code};
    final sentLots = {for (final q in local.quarantine) q.lotId};
    final updated = latest.copyWith(
      scans: [for (final s in latest.scans) sent.contains(s.code) ? s.asSynced : s],
      quarantine: [
        for (final q in latest.quarantine)
          if (!sentLots.contains(q.lotId)) q,
      ],
      lastSyncAt: _clock(),
    );
    await _store.save(uid, loadId, updated);
    return updated;
  }
}

/// "Confirm stock" (Stock 15 → 06): every portion scanned and synced. Go
/// online unlocks. Needs signal.
class ConfirmStock {
  const ConfirmStock(this._record, this._signal);

  final RecordStockScans _record;
  final SignalRepository _signal;

  Future<void> call(String uid, Shift shift, StockTally tally) async {
    if (!tally.allScanned) throw const AppException();
    if (tally.waitingToSync > 0 || !await _signal.isOnline()) {
      throw const AppException();
    }
    await _record(uid, shift, tally.portionsLoaded, confirm: true).timeout(stockCallTimeout);
  }
}

/// A camera sees the same code many times a second. A code counts again only
/// after it has been out of sight for [quiet], so pointing back at a label
/// later still reads as "already scanned" (Stock 10).
class RepeatCodeFilter {
  RepeatCodeFilter(this._clock, {this.quiet = const Duration(seconds: 3)});

  final DateTime Function() _clock;
  final Duration quiet;
  final _lastSeen = <String, DateTime>{};

  /// Whether [code] should be handled now.
  bool accept(String code) {
    final now = _clock();
    final last = _lastSeen[code];
    _lastSeen[code] = now;
    return last == null || now.difference(last) >= quiet;
  }
}

/// What this phone holds of the load, without going to the network.
class LoadStockScans {
  const LoadStockScans(this._store);

  final StockScanStore _store;

  Future<StockLocalState> call(String uid, String shiftId) => _store.load(uid, shiftId);
}
