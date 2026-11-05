import '../../../../core/config/demo_data.dart';
import '../../domain/entities/stock.dart';
import '../../domain/repositories/stock_repository.dart';

/// The sample load, with a short wait on the lot check so "Checking item…"
/// (Stock 12) shows.
class DemoStockRepository implements StockRepository {
  DemoStockRepository(this._clock);

  final DateTime Function() _clock;
  final _uploaded = <String, List<StockScan>>{};
  final _prepared = <String, List<StockItem>>{};

  /// B-2207 always expired half an hour ago.
  Map<String, StockLot> get _lots {
    final now = _clock();
    return {
      DemoData.goodLot: StockLot(id: DemoData.goodLot, itemId: 'smash-burger', expiresAt: now.add(DemoData.lotLife)),
      DemoData.expiredLot: StockLot(
        id: DemoData.expiredLot,
        itemId: 'smash-burger',
        expiresAt: now.subtract(const Duration(minutes: 30)),
      ),
      DemoData.warmLot: const StockLot(
        id: DemoData.warmLot,
        itemId: 'paneer-tikka-wrap',
        temperatureC: 12,
        maxTemperatureC: 8,
      ),
    };
  }

  @override
  Future<StockManifest> manifest(String uid, String shiftId) async => StockManifest(
    items:
        _prepared[shiftId] ??
        [
          for (final (id, name, quantity, image) in DemoData.stockList)
            StockItem(id: id, name: name, quantity: quantity, image: image),
        ],
    lots: _lots,
  );

  @override
  Future<void> prepareLoad(String uid, String shiftId, List<StockItem> items) async => _prepared[shiftId] = items;

  @override
  Future<List<StockScan>> uploadedScans(String uid, String shiftId) async => List.of(_uploaded[shiftId] ?? const []);

  @override
  Future<StockLot?> lot(String uid, String shiftId, String lotId) async {
    await Future<void>.delayed(DemoData.lotCheck);
    return _lots[lotId];
  }

  @override
  Future<void> uploadScans(String uid, String shiftId, List<StockScan> scans) async =>
      (_uploaded[shiftId] ??= []).addAll(scans.map((s) => s.asSynced));

  @override
  Future<void> moveToQuarantine(String uid, String shiftId, QuarantineRequest request) async {}
}
