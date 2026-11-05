import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_mode.dart';
import '../../../core/di/clock_provider.dart';
import '../../../core/di/firebase_providers.dart';
import '../../shift/di/shift_di.dart';
import '../data/repositories/demo_stock_repository.dart';
import '../data/repositories/firestore_stock_repository.dart';
import '../data/repositories/local_stock_stores.dart';
import '../data/repositories/signal_repositories.dart';
import '../domain/repositories/stock_repository.dart';
import '../domain/usecases/signal_usecases.dart';
import '../domain/usecases/stock_usecases.dart';

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => kDemoMode
      ? DemoStockRepository(ref.watch(clockProvider))
      : FirestoreStockRepository(ref.watch(firestoreProvider)),
);

final stockScanStoreProvider = Provider<StockScanStore>(
  (ref) => kDemoMode ? InMemoryStockScanStore() : PrefsStockScanStore(),
);

final signalRepositoryProvider = Provider<SignalRepository>((ref) {
  if (!kDemoMode) return ConnectivitySignalRepository();
  final demo = DemoSignalRepository();
  ref.onDispose(demo.dispose);
  return demo;
});

/// Switches the demo's signal; null outside demo mode.
final demoSignalProvider = Provider<DemoSignalRepository?>((ref) {
  final signal = ref.watch(signalRepositoryProvider);
  return signal is DemoSignalRepository ? signal : null;
});

final loadStockUseCaseProvider = Provider(
  (ref) => LoadStock(ref.watch(stockRepositoryProvider), ref.watch(stockScanStoreProvider)),
);
final processScanUseCaseProvider = Provider(
  (ref) => ProcessScan(
    ref.watch(stockRepositoryProvider),
    ref.watch(stockScanStoreProvider),
    ref.watch(signalRepositoryProvider),
    ref.watch(clockProvider),
  ),
);
final saveManualCountsUseCaseProvider = Provider(
  (ref) => SaveManualCounts(ref.watch(stockScanStoreProvider), ref.watch(clockProvider)),
);
final moveLotToQuarantineUseCaseProvider = Provider(
  (ref) => MoveLotToQuarantine(ref.watch(stockScanStoreProvider), ref.watch(clockProvider)),
);
final syncStockScansUseCaseProvider = Provider(
  (ref) => SyncStockScans(
    ref.watch(stockRepositoryProvider),
    ref.watch(stockScanStoreProvider),
    ref.watch(recordStockScansUseCaseProvider),
    ref.watch(clockProvider),
  ),
);
final confirmStockUseCaseProvider = Provider(
  (ref) => ConfirmStock(ref.watch(recordStockScansUseCaseProvider), ref.watch(signalRepositoryProvider)),
);

final checkSignalUseCaseProvider = Provider((ref) => CheckSignal(ref.watch(signalRepositoryProvider)));
final watchSignalUseCaseProvider = Provider((ref) => WatchSignal(ref.watch(signalRepositoryProvider)));
final loadStockScansUseCaseProvider = Provider((ref) => LoadStockScans(ref.watch(stockScanStoreProvider)));
