import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/app_mode.dart';
import '../../../core/config/demo_data.dart';
import '../../../core/di/clock_provider.dart';
import '../../../core/di/firebase_providers.dart';
import '../../location/di/location_di.dart';
import '../../stock/di/stock_di.dart';
import '../data/repositories/demo_shift_repository.dart';
import '../data/repositories/device_status_repository_impl.dart';
import '../data/repositories/firestore_shift_repository.dart';
import '../data/repositories/local_shift_notifier.dart';
import '../data/repositories/route_repositories.dart';
import '../domain/repositories/device_status_repository.dart';
import '../domain/repositories/route_repository.dart';
import '../domain/repositories/shift_notifier.dart';
import '../domain/repositories/shift_repository.dart';
import '../domain/usecases/home_status_of.dart';
import '../domain/usecases/plan_shift_pushes.dart';
import '../domain/usecases/route_usecases.dart';
import '../domain/usecases/shift_flow_usecases.dart';
import '../domain/usecases/shift_push_usecases.dart';
import '../domain/usecases/stock_request_usecases.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  if (!kDemoMode) return FirestoreShiftRepository(ref.watch(firestoreProvider), ref.watch(clockProvider));
  final demo = DemoShiftRepository();
  ref.onDispose(demo.dispose);
  return demo;
});

/// When the stock-request pushes go out: 1 h and 30 min before the shift;
/// in demo mode a few seconds after the app opens.
final pushTimesProvider = Provider<PushTimes>((ref) {
  final repository = ref.watch(shiftRepositoryProvider);
  return repository is DemoShiftRepository ? DemoPushTimes(repository.opened) : const ShiftPushTimes();
});

final shiftNotifierProvider = Provider<ShiftNotifier>((ref) => LocalShiftNotifier());

final deviceStatusRepositoryProvider = Provider<DeviceStatusRepository>((ref) => PhoneDeviceStatusRepository());

final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => kDemoMode ? const DemoRouteRepository(DemoData.hubDistanceKm) : const StraightLineRouteRepository(),
);

/// The rider's position on the way to the hub. Demo: a fixed point about
/// 1.2 km from the sample hub (emulators sit far away).
final tripPositionSourceProvider = Provider<Stream<LatLng> Function()>((ref) {
  if (kDemoMode) return () => Stream.value(const LatLng(DemoData.riderLat, DemoData.riderLng));
  final watch = ref.watch(watchDevicePositionUseCaseProvider);
  return () => watch();
});

final watchTodayShiftUseCaseProvider = Provider((ref) => WatchTodayShift(ref.watch(shiftRepositoryProvider)));
final homeStatusOfUseCaseProvider = Provider((ref) => const HomeStatusOf());
final replyToStockRequestUseCaseProvider = Provider((ref) => ReplyToStockRequest(ref.watch(shiftRepositoryProvider)));
final startShiftUseCaseProvider = Provider(
  (ref) => StartShift(ref.watch(shiftRepositoryProvider), ref.watch(clockProvider)),
);
final checkPreShiftItemUseCaseProvider = Provider(
  (ref) => CheckPreShiftItem(ref.watch(deviceStatusRepositoryProvider)),
);
final finishChecklistUseCaseProvider = Provider((ref) => FinishChecklist(ref.watch(shiftRepositoryProvider)));
final arriveAtHubUseCaseProvider = Provider((ref) => ArriveAtHub(ref.watch(shiftRepositoryProvider)));
final startScanningUseCaseProvider = Provider((ref) => StartScanning(ref.watch(shiftRepositoryProvider)));
final recordStockScansUseCaseProvider = Provider((ref) => RecordStockScans(ref.watch(shiftRepositoryProvider)));
final goOnlineUseCaseProvider = Provider(
  (ref) => GoOnline(ref.watch(shiftRepositoryProvider), ref.watch(signalRepositoryProvider)),
);
final planShiftPushesUseCaseProvider = Provider((ref) => PlanShiftPushes(ref.watch(pushTimesProvider)));

final nextHubStepUseCaseProvider = Provider((ref) => NextRouteStep(ref.watch(routeRepositoryProvider)));
final initPushesUseCaseProvider = Provider((ref) => InitPushes(ref.watch(shiftNotifierProvider)));
final watchPushActionsUseCaseProvider = Provider((ref) => WatchPushActions(ref.watch(shiftNotifierProvider)));
final watchOpenedPushesUseCaseProvider = Provider((ref) => WatchOpenedPushes(ref.watch(shiftNotifierProvider)));
final schedulePushUseCaseProvider = Provider((ref) => SchedulePush(ref.watch(shiftNotifierProvider)));
final showPushUseCaseProvider = Provider((ref) => ShowPush(ref.watch(shiftNotifierProvider)));
final cancelPushUseCaseProvider = Provider((ref) => CancelPush(ref.watch(shiftNotifierProvider)));
