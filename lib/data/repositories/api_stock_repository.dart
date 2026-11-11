import '../../core/errors/app_exception.dart';
import '../../domain/entities/stock.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/remote/rider_api_client.dart';
import '../datasources/remote/rider_api_session.dart';
import '../datasources/remote/rider_event_queue.dart';

/// The scooter's stock on the rider API. A scan loads a whole lot
/// (`POST /riders/me/stock/scan`); there's no packed list to scan against, so
/// the load is what has been scanned so far (`GET /riders/me/stock`): an open
/// manifest, one scan per portion, all already on the server. A refill's
/// load is the lots scanned during it.
class ApiStockRepository implements StockRepository, LotScanRepository {
  ApiStockRepository(this._session);

  final RiderApiSession _session;

  /// The day's own load counts every lot on the scooter.
  bool _isDayLoad(String loadId) => !loadId.contains('-refill');

  List<Map<String, dynamic>> _lotsOf(String loadId) {
    if (_isDayLoad(loadId)) return _session.lots;
    final scanned = {...((_session.day['loadLots'] as Map<String, dynamic>?)?[loadId] as List? ?? const [])};
    return [
      for (final lot in _session.lots)
        if (scanned.contains(lot['lot_id'])) lot,
    ];
  }

  StockManifest _manifest(String loadId) {
    final quantities = <String, int>{};
    final images = <String, String>{};
    final lots = <String, StockLot>{};
    for (final lot in _lotsOf(loadId)) {
      final item = lot['item_id'] as String;
      quantities[item] = (quantities[item] ?? 0) + ((lot['qty'] as num?)?.toInt() ?? 0);
      // The menu item's photo (`image_url`), null when it has none.
      final image = lot['image_url'] as String?;
      if (image != null) images[item] = image;
      lots[lot['lot_id'] as String] = _lot(lot);
    }
    return StockManifest(
      items: [
        for (final MapEntry(:key, :value) in quantities.entries)
          StockItem(id: key, name: _session.itemName(key), quantity: value, image: images[key]),
      ],
      lots: lots,
      open: true,
    );
  }

  static StockLot _lot(Map<String, dynamic> json) => StockLot(
    id: json['lot_id'] as String,
    itemId: json['item_id'] as String,
    expiresAt: RiderApiSession.parseTime(json['expiry']),
  );

  List<StockScan> _scans(String loadId) {
    final now = _session.clock();
    return [
      for (final lot in _lotsOf(loadId))
        for (var n = 1; n <= ((lot['qty'] as num?)?.toInt() ?? 0); n++)
          StockScan(
            code: '${lot['lot_id']}#$n',
            itemId: lot['item_id'] as String,
            lotId: lot['lot_id'] as String,
            at: now,
            synced: true,
          ),
    ];
  }

  Future<void> _fetch() async {
    try {
      await _session.refreshStock();
    } on RiderApiException catch (e) {
      throw AppException(e.code);
    }
    // The shift's load follows.
    _session.notify();
  }

  @override
  Future<StockManifest> manifest(String uid, String shiftId) async {
    await _session.ensureLoaded();
    await _fetch();
    return _manifest(shiftId);
  }

  @override
  Future<List<StockScan>> uploadedScans(String uid, String shiftId) async => _scans(shiftId);

  @override
  Future<LotScan> scanLot(String uid, String loadId, String code, DateTime at) async {
    final Map<String, dynamic> unit;
    final event = _session.events.event('stock_scan', {'lot_code': code}, at: at);
    try {
      unit =
          (await _session.api.scanStock({
                'lot_code': code,
                'scanned_at': at.toUtc().toIso8601String(),
              }, idempotencyKey: event['event_id'] as String))['unit']
              as Map<String, dynamic>;
    } on RiderApiException catch (e) {
      // Without a way through the lot loads with the event batch later; the
      // screen stays as it was until then.
      if (RiderEventQueue.isOffline(e)) {
        await _session.events.add(event);
        throw const AppException('stock_scan_queued');
      }
      final status = switch (e.code) {
        'lot_already_on_scooter' => LotScanStatus.alreadyLoaded,
        'lot_expired' => LotScanStatus.expired,
        'bad_scan' || 'lot_not_expected' || 'lot_quarantined' => LotScanStatus.notOnList,
        // no_open_shift, no signal: the screen stays as it was.
        _ => throw AppException(e.code),
      };
      final known = _session.lots.where((l) => l['lot_id'] == code).firstOrNull;
      final item = known == null ? null : _manifest(loadId).item(known['item_id'] as String);
      return LotScan(status, item: item, lot: known == null ? null : _lot(known));
    }
    final lotId = unit['lot_id'] as String;
    if (!_isDayLoad(loadId)) {
      final loads = {...?(_session.day['loadLots'] as Map<String, dynamic>?)};
      loads[loadId] = {...(loads[loadId] as List? ?? const []), lotId}.toList();
      await _session.setDay({'loadLots': loads});
    }
    await _fetch();
    final manifest = _manifest(loadId);
    final itemId = unit['item_id'] as String;
    return LotScan(
      unit['temp_status'] == 'alert' ? LotScanStatus.tooWarm : LotScanStatus.loaded,
      item: manifest.item(itemId) ?? StockItem(id: itemId, name: _session.itemName(itemId), quantity: 0),
      lot: StockLot(id: lotId, itemId: itemId, expiresAt: RiderApiSession.parseTime(unit['expiry'])),
      manifest: manifest,
      scans: _scans(loadId),
    );
  }

  /// A lot's facts come with its scan.
  @override
  Future<StockLot?> lot(String uid, String shiftId, String lotId) async => null;

  /// Every scan is on the server already.
  @override
  Future<void> uploadScans(String uid, String shiftId, List<StockScan> scans) async {}

  /// The API has no quarantine call; the temperature alert is the server's.
  @override
  Future<void> moveToQuarantine(String uid, String shiftId, QuarantineRequest request) async {}

  /// There's nothing to prepare: a restock is confirmed on its own screens.
  @override
  Future<void> prepareLoad(String uid, String shiftId, List<StockItem> items) async {}
}
