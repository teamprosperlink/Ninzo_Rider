import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/stock.dart';
import '../../../domain/repositories/stock_repository.dart';
import '../../models/stock_models.dart';

/// Scans saved on the phone, one JSON document per rider and shift.
class PrefsStockScanStore implements StockScanStore {
  static String _key(String uid, String shiftId) => 'stock_scans/$uid/$shiftId';

  @override
  Future<StockLocalState> load(String uid, String shiftId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid, shiftId));
    if (raw == null) return const StockLocalState();
    return StockLocalJson.decode((jsonDecode(raw) as Map).cast<String, dynamic>());
  }

  @override
  Future<void> save(String uid, String shiftId, StockLocalState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid, shiftId), jsonEncode(StockLocalJson.encode(state)));
  }
}

/// Kept in memory: the demo's shift starts afresh on each launch, so its scans
/// must too.
class InMemoryStockScanStore implements StockScanStore {
  final _states = <String, StockLocalState>{};

  @override
  Future<StockLocalState> load(String uid, String shiftId) async =>
      _states['$uid/$shiftId'] ?? const StockLocalState();

  @override
  Future<void> save(String uid, String shiftId, StockLocalState state) async => _states['$uid/$shiftId'] = state;
}
