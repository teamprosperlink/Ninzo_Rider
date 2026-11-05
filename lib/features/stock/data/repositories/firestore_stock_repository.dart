import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/firebase_error_mapper.dart';
import '../../domain/entities/stock.dart';
import '../../domain/repositories/stock_repository.dart';
import '../models/stock_models.dart';

/// The backend writes the load (`stock.list`, `stock.lots`) on the shift; the
/// rider adds to its `scans` and `quarantine` subcollections. A refill's load
/// id is `<shift id>-refill<n>`: its load is `refills.<n>.stock` on the shift,
/// its scans `refill<n>Scans`.
class FirestoreStockRepository implements StockRepository {
  FirestoreStockRepository(this._firestore);

  final FirebaseFirestore _firestore;

  static final _refillLoad = RegExp(r'^(.+)-refill(\d+)$');

  DocumentReference<Map<String, dynamic>> _shift(String uid, String loadId) => _firestore
      .collection('riders')
      .doc(uid)
      .collection('shifts')
      .doc(_refillLoad.firstMatch(loadId)?.group(1) ?? loadId);

  static String? _round(String loadId) => _refillLoad.firstMatch(loadId)?.group(2);

  static String _scans(String loadId) => switch (_round(loadId)) {
    final round? => 'refill${round}Scans',
    null => 'scans',
  };

  /// The part of the shift document holding this load.
  static Map<String, dynamic> _load(Map<String, dynamic>? shift, String loadId) {
    final round = _round(loadId);
    if (round == null) return shift ?? const {};
    final refills = (shift?['refills'] as Map?)?.cast<String, dynamic>();
    return (refills?[round] as Map?)?.cast<String, dynamic>() ?? const {};
  }

  /// Codes can hold any character; document ids can't hold "/".
  static String _docId(String code) => code.replaceAll('/', '_');

  @override
  Future<StockManifest> manifest(String uid, String shiftId) => guardFirebase(() async {
    final doc = await _shift(uid, shiftId).get();
    return StockFirestore.manifest(_load(doc.data(), shiftId));
  });

  /// TODO(backend): pack this and write it to `refills.<n>.stock`.
  @override
  Future<void> prepareLoad(String uid, String shiftId, List<StockItem> items) => guardFirebase(
    () => _shift(uid, shiftId).update({
      'refillRequest': {
        'loadId': shiftId,
        'items': [
          for (final item in items) {'id': item.id, 'name': item.name, 'quantity': item.quantity},
        ],
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  @override
  Future<List<StockScan>> uploadedScans(String uid, String shiftId) => guardFirebase(() async {
    final docs = await _shift(uid, shiftId).collection(_scans(shiftId)).get();
    return [for (final d in docs.docs) StockFirestore.scan(d.data())];
  });

  @override
  Future<StockLot?> lot(String uid, String shiftId, String lotId) => guardFirebase(() async {
    // From the server: a cached reading is what the phone already has.
    final doc = await _shift(uid, shiftId).get(const GetOptions(source: Source.server));
    return StockFirestore.manifest(_load(doc.data(), shiftId)).lots[lotId];
  });

  @override
  Future<void> uploadScans(String uid, String shiftId, List<StockScan> scans) => guardFirebase(() async {
    final batch = _firestore.batch();
    final collection = _shift(uid, shiftId).collection(_scans(shiftId));
    for (final s in scans) {
      batch.set(collection.doc(_docId(s.code)), {
        'code': s.code,
        'itemId': s.itemId,
        'lotId': s.lotId,
        'method': s.method.name,
        'scannedAt': Timestamp.fromDate(s.at),
        'syncedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  });

  @override
  Future<void> moveToQuarantine(String uid, String shiftId, QuarantineRequest request) => guardFirebase(
    () => _shift(uid, shiftId).collection('quarantine').doc(request.lotId).set({
      'lotId': request.lotId,
      'itemId': request.itemId,
      'requestedAt': Timestamp.fromDate(request.at),
    }),
  );
}
