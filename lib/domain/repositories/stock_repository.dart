import '../entities/stock.dart';

/// Today's load on the backend. Any call can fail without signal.
abstract interface class StockRepository {
  /// What the hub packed for this shift.
  Future<StockManifest> manifest(String uid, String shiftId);

  /// Asks the hub to pack [items] as load [shiftId] (a restock's own choice).
  Future<void> prepareLoad(String uid, String shiftId, List<StockItem> items);

  /// Portions already uploaded (e.g. from before a reinstall).
  Future<List<StockScan>> uploadedScans(String uid, String shiftId);

  /// The lot's latest expiry and temperature; null when the backend has no
  /// such lot.
  Future<StockLot?> lot(String uid, String shiftId, String lotId);

  Future<void> uploadScans(String uid, String shiftId, List<StockScan> scans);

  Future<void> moveToQuarantine(String uid, String shiftId, QuarantineRequest request);
}

/// A backend that loads whole lots by their code (the rider API): it says what
/// the code is, so there's no packed list to check it against first.
abstract interface class LotScanRepository {
  /// Needs signal.
  Future<LotScan> scanLot(String uid, String loadId, String code, DateTime at);
}

/// The phone's own copy of a shift's scans.
abstract interface class StockScanStore {
  Future<StockLocalState> load(String uid, String shiftId);

  Future<void> save(String uid, String shiftId, StockLocalState state);
}

/// Whether the phone has signal.
abstract interface class SignalRepository {
  Future<bool> isOnline();

  /// Each change, as it happens.
  Stream<bool> watchOnline();
}
