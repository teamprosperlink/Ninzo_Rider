
import '../../domain/entities/stock.dart';

/// JSON for the phone's copy (dates as ISO strings).
abstract final class StockLocalJson {
  static Map<String, dynamic> encode(StockLocalState s) => {
    if (s.manifest != null) 'manifest': _manifest(s.manifest!),
    'scans': [
      for (final scan in s.scans)
        {
          'code': scan.code,
          'itemId': scan.itemId,
          'lotId': scan.lotId,
          'method': scan.method.name,
          'at': scan.at.toIso8601String(),
          'synced': scan.synced,
        },
    ],
    'quarantine': [
      for (final q in s.quarantine) {'lotId': q.lotId, 'itemId': q.itemId, 'at': q.at.toIso8601String()},
    ],
    if (s.lastSyncAt != null) 'lastSyncAt': s.lastSyncAt!.toIso8601String(),
  };

  static StockLocalState decode(Map<String, dynamic> j) => StockLocalState(
    manifest: j['manifest'] == null ? null : _parseManifest((j['manifest'] as Map).cast<String, dynamic>()),
    scans: [
      for (final raw in j['scans'] as List? ?? const [])
        StockFirestore.scan((raw as Map).cast<String, dynamic>()),
    ],
    quarantine: [
      for (final raw in j['quarantine'] as List? ?? const [])
        QuarantineRequest(
          lotId: (raw as Map)['lotId'] as String,
          itemId: raw['itemId'] as String,
          at: DateTime.parse(raw['at'] as String),
        ),
    ],
    lastSyncAt: j['lastSyncAt'] == null ? null : DateTime.parse(j['lastSyncAt'] as String),
  );

  static Map<String, dynamic> _manifest(StockManifest m) => {
    'list': [
      for (final i in m.items) {'id': i.id, 'name': i.name, 'quantity': i.quantity, 'imageUrl': i.image},
    ],
    'lots': {
      for (final l in m.lots.values)
        l.id: {
          'itemId': l.itemId,
          'expiresAt': l.expiresAt?.toIso8601String(),
          'temperatureC': l.temperatureC,
          'maxTemperatureC': l.maxTemperatureC,
        },
    },
  };

  static StockManifest _parseManifest(Map<String, dynamic> j) => StockFirestore.manifest({'stock': j});
}

/// The stock list and scans as the phone keeps them (the shape the older
/// Firestore backend used for `riders/{uid}/shifts/{id}`):
///
/// ```text
/// stock.list   [{id, name, imageUrl, quantity}]
/// stock.lots   {lotId: {itemId, expiresAt, temperatureC, maxTemperatureC}}
/// ```
///
/// and `riders/{uid}/shifts/{id}/scans/{code}`:
/// `{code, itemId, lotId, method, scannedAt, syncedAt}`.
abstract final class StockFirestore {
  static DateTime? _date(Object? value) => switch (value) {
    final String s => DateTime.parse(s),
    _ => null,
  };

  static StockManifest manifest(Map<String, dynamic> shift) {
    final stock = (shift['stock'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StockManifest(
      items: [
        for (final raw in stock['list'] as List? ?? const [])
          StockItem(
            id: (raw as Map)['id'] as String,
            name: raw['name'] as String,
            quantity: (raw['quantity'] as num).toInt(),
            image: raw['imageUrl'] as String?,
          ),
      ],
      lots: {
        for (final e in (stock['lots'] as Map? ?? const {}).entries)
          e.key as String: StockLot(
            id: e.key as String,
            itemId: (e.value as Map)['itemId'] as String,
            expiresAt: _date(e.value['expiresAt']),
            temperatureC: (e.value['temperatureC'] as num?)?.toDouble(),
            maxTemperatureC: (e.value['maxTemperatureC'] as num?)?.toDouble(),
          ),
      },
    );
  }

  /// A scan document, or a saved scan from the phone's copy (`at`, `synced`).
  static StockScan scan(Map<String, dynamic> j) => StockScan(
    code: j['code'] as String,
    itemId: j['itemId'] as String,
    lotId: j['lotId'] as String?,
    method: j['method'] == 'manual' ? ScanMethod.manual : ScanMethod.qr,
    at: _date(j['scannedAt'] ?? j['at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    synced: j['synced'] as bool? ?? true,
  );
}
