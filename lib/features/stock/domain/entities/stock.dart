/// One menu item in today's load, e.g. "Smash Burger × 2".
class StockItem {
  const StockItem({required this.id, required this.name, required this.quantity, this.image});

  final String id;
  final String name;

  /// Portions the hub packed.
  final int quantity;

  /// Photo: a network URL, or an `assets/` path for the demo.
  final String? image;
}

/// A batch the hub packed. The backend keeps its expiry and cold-chain
/// reading up to date.
class StockLot {
  const StockLot({required this.id, required this.itemId, this.expiresAt, this.temperatureC, this.maxTemperatureC});

  /// e.g. "B-2207".
  final String id;
  final String itemId;
  final DateTime? expiresAt;

  /// Latest reading, °C.
  final double? temperatureC;

  /// Warmest the lot may get, °C.
  final double? maxTemperatureC;

  bool isExpired(DateTime now) => expiresAt != null && now.isAfter(expiresAt!);

  bool get isTooWarm => temperatureC != null && maxTemperatureC != null && temperatureC! > maxTemperatureC!;
}

/// Today's load: what the hub packed for this rider.
class StockManifest {
  const StockManifest({required this.items, this.lots = const {}});

  final List<StockItem> items;

  /// By lot id.
  final Map<String, StockLot> lots;

  int get portions => items.fold(0, (sum, item) => sum + item.quantity);

  StockItem? item(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}

enum ScanMethod {
  /// The item's QR code.
  qr,

  /// "Enter counts" (Stock 05), when a QR code won't scan.
  manual,
}

/// One portion confirmed on the scooter. Saved on the phone first, then
/// uploaded when there is signal.
class StockScan {
  const StockScan({
    required this.code,
    required this.itemId,
    this.lotId,
    this.method = ScanMethod.qr,
    required this.at,
    this.synced = false,
  });

  /// What identifies this portion: the QR code, or a generated manual id.
  final String code;
  final String itemId;
  final String? lotId;
  final ScanMethod method;
  final DateTime at;

  /// Uploaded to the backend.
  final bool synced;

  StockScan get asSynced => StockScan(code: code, itemId: itemId, lotId: lotId, method: method, at: at, synced: true);
}

/// "Move to quarantine" (Stock 08), waiting for signal like a scan.
class QuarantineRequest {
  const QuarantineRequest({required this.lotId, required this.itemId, required this.at});

  final String lotId;
  final String itemId;
  final DateTime at;
}

/// What the phone keeps for a shift, so scans survive no signal and restarts.
class StockLocalState {
  const StockLocalState({this.manifest, this.scans = const [], this.quarantine = const [], this.lastSyncAt});

  /// The last load fetched, for scanning without signal.
  final StockManifest? manifest;
  final List<StockScan> scans;

  /// Not uploaded yet.
  final List<QuarantineRequest> quarantine;
  final DateTime? lastSyncAt;

  StockLocalState copyWith({
    StockManifest? manifest,
    List<StockScan>? scans,
    List<QuarantineRequest>? quarantine,
    DateTime? lastSyncAt,
  }) => StockLocalState(
    manifest: manifest ?? this.manifest,
    scans: scans ?? this.scans,
    quarantine: quarantine ?? this.quarantine,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );
}

/// Today's load against what has been scanned.
class StockTally {
  const StockTally(this.manifest, this.scans);

  final StockManifest manifest;
  final List<StockScan> scans;

  int count(String itemId) => scans.where((s) => s.itemId == itemId).length;

  bool isLoaded(StockItem item) => count(item.id) >= item.quantity;

  bool hasCode(String code) => scans.any((s) => s.code == code);

  /// "Portions loaded · 3 of 6".
  int get portionsLoaded => scans.length;
  int get portions => manifest.portions;

  /// "Items loaded · 4 of 4".
  int get itemsLoaded => manifest.items.where(isLoaded).length;
  int get items => manifest.items.length;

  bool get allScanned => portions > 0 && manifest.items.every(isLoaded);

  /// "Waiting to sync · 3 scans".
  int get waitingToSync => scans.where((s) => !s.synced).length;
}

/// What an item's QR code says: `NZ1|<item id>|<lot id>|<portion number>`.
// TODO(backend): agree the label format with the hub's printing.
class ScanCode {
  const ScanCode({required this.itemId, required this.lotId, required this.portion});

  final String itemId;
  final String lotId;
  final String portion;

  static const _prefix = 'NZ1';

  String get raw => '$_prefix|$itemId|$lotId|$portion';

  /// Null when it isn't one of our labels.
  static ScanCode? parse(String raw) {
    final parts = raw.trim().split('|');
    if (parts.length != 4 || parts.first != _prefix || parts.skip(1).any((p) => p.isEmpty)) return null;
    return ScanCode(itemId: parts[1], lotId: parts[2], portion: parts[3]);
  }
}
