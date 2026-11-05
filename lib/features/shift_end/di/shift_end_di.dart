import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_mode.dart';
import '../../../core/di/firebase_providers.dart';
import '../../online/di/online_di.dart';
import '../../orders/di/orders_di.dart';
import '../../shift/di/shift_di.dart';
import '../../stock/data/repositories/signal_repositories.dart';
import '../../stock/di/stock_di.dart';
import '../data/repositories/device_health_repositories.dart';
import '../data/repositories/shift_session_repositories.dart';
import '../data/repositories/sync_status_repositories.dart';
import '../domain/repositories/shift_end_repositories.dart';
import '../domain/usecases/shift_end_usecases.dart';

final deviceHealthRepositoryProvider = Provider<DeviceHealthRepository>(
  (ref) => kDemoMode ? DemoDeviceHealthRepository() : PhoneDeviceHealthRepository(ref.watch(deviceStatusRepositoryProvider)),
);

final shiftSessionRepositoryProvider = Provider<ShiftSessionRepository>(
  (ref) => kDemoMode ? DemoShiftSessionRepository() : FirestoreShiftSessionRepository(ref.watch(firestoreProvider)),
);

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  final local = LocalSyncStatusRepository(ref.watch(handoverStoreProvider), ref.watch(syncSavedHandoversUseCaseProvider));
  if (!kDemoMode) return local;
  final signal = ref.watch(signalRepositoryProvider);
  return DemoSyncStatusRepository(local, signal is DemoSignalRepository ? signal : null);
});

/// What the demo pills play; null outside demo mode.
final demoDeviceHealthProvider = Provider<DemoDeviceHealthRepository?>((ref) {
  final repository = ref.watch(deviceHealthRepositoryProvider);
  return repository is DemoDeviceHealthRepository ? repository : null;
});
final demoShiftSessionProvider = Provider<DemoShiftSessionRepository?>((ref) {
  final repository = ref.watch(shiftSessionRepositoryProvider);
  return repository is DemoShiftSessionRepository ? repository : null;
});
final demoSyncStatusProvider = Provider<DemoSyncStatusRepository?>((ref) {
  final repository = ref.watch(syncStatusRepositoryProvider);
  return repository is DemoSyncStatusRepository ? repository : null;
});

final openShiftUseCaseProvider = Provider(
  (ref) => OpenShift(ref.watch(signalRepositoryProvider), ref.watch(shiftSessionRepositoryProvider)),
);
final checkDeviceHealthUseCaseProvider = Provider((ref) => CheckDeviceHealth(ref.watch(deviceHealthRepositoryProvider)));
final endShiftUseCaseProvider = Provider(
  (ref) => EndShift(
    ref.watch(shiftRepositoryProvider),
    ref.watch(onlineRepositoryProvider),
    ref.watch(shiftSessionRepositoryProvider),
  ),
);

final loadSyncStatusUseCaseProvider = Provider((ref) => LoadSyncStatus(ref.watch(syncStatusRepositoryProvider)));
final retrySyncUseCaseProvider = Provider((ref) => RetrySync(ref.watch(syncStatusRepositoryProvider)));
final isLocationOnUseCaseProvider = Provider((ref) => IsLocationOn(ref.watch(deviceHealthRepositoryProvider)));
final isPhoneTimeAutomaticUseCaseProvider = Provider(
  (ref) => IsPhoneTimeAutomatic(ref.watch(deviceHealthRepositoryProvider)),
);
final openLocationSettingsUseCaseProvider = Provider(
  (ref) => OpenLocationSettings(ref.watch(deviceHealthRepositoryProvider)),
);
final openDateSettingsUseCaseProvider = Provider((ref) => OpenDateSettings(ref.watch(deviceHealthRepositoryProvider)));
