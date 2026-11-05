import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_mode.dart';
import '../../../core/di/clock_provider.dart';
import '../../../core/di/firebase_providers.dart';
import '../../location/di/location_di.dart';
import '../../location/domain/repositories/location_repository.dart';
import '../../location/domain/usecases/watch_device_position.dart';
import '../../shift/data/repositories/route_repositories.dart';
import '../../shift/di/shift_di.dart';
import '../../shift/domain/repositories/route_repository.dart';
import '../../shift/domain/usecases/route_usecases.dart';
import '../../stock/di/stock_di.dart';
import '../data/repositories/demo_online_repository.dart';
import '../data/repositories/demo_rider_location.dart';
import '../data/repositories/firestore_online_repository.dart';
import '../data/repositories/spot_choice_repositories.dart';
import '../domain/repositories/online_repository.dart';
import '../domain/repositories/spot_choice_repository.dart';
import '../domain/usecases/break_usecases.dart';
import '../domain/usecases/choose_spot_usecases.dart';
import '../domain/usecases/online_usecases.dart';
import '../domain/usecases/plan_online_pushes.dart';
import '../domain/usecases/relocation_usecases.dart';
import '../domain/usecases/spot_usecases.dart';

final onlineRepositoryProvider = Provider<OnlineRepository>((ref) {
  if (!kDemoMode) return FirestoreOnlineRepository(ref.watch(firestoreProvider));
  final demo = DemoOnlineRepository(ref.watch(clockProvider));
  ref.onDispose(demo.dispose);
  return demo;
});

/// The rider's position around the spot. Demo: simulated, about 1.2 km away.
final riderLocationProvider = Provider<LocationRepository>((ref) {
  if (!kDemoMode) return ref.watch(locationRepositoryProvider);
  final demo = DemoRiderLocation();
  ref.onDispose(demo.dispose);
  return demo;
});

/// Plays the backend in demo mode; null otherwise.
final demoOnlineProvider = Provider<DemoOnlineRepository?>((ref) {
  final repository = ref.watch(onlineRepositoryProvider);
  return repository is DemoOnlineRepository ? repository : null;
});

/// Moves the demo rider; null outside demo mode.
final demoRiderLocationProvider = Provider<DemoRiderLocation?>((ref) {
  final location = ref.watch(riderLocationProvider);
  return location is DemoRiderLocation ? location : null;
});

/// Choose a spot (Shift 13–18). Only the demo has spots to choose from.
final spotChoiceRepositoryProvider = Provider<SpotChoiceRepository>(
  (ref) => kDemoMode ? DemoSpotChoiceRepository() : const NoSpotChoices(),
);

/// Plays the backend on Choose a spot; null outside demo mode.
final demoSpotChoiceProvider = Provider<DemoSpotChoiceRepository?>((ref) {
  final repository = ref.watch(spotChoiceRepositoryProvider);
  return repository is DemoSpotChoiceRepository ? repository : null;
});

final spotRouteRepositoryProvider = Provider<RouteRepository>(
  (ref) => kDemoMode ? const DemoSpotRouteRepository() : const StraightLineRouteRepository(),
);

final planOnlinePushesUseCaseProvider = Provider((ref) => const PlanOnlinePushes());
final watchOnlineStatusUseCaseProvider = Provider((ref) => WatchOnlineStatus(ref.watch(onlineRepositoryProvider)));
final checkAtSpotUseCaseProvider = Provider((ref) => CheckAtSpot(ref.watch(riderLocationProvider)));
final goOnlineAtSpotUseCaseProvider = Provider(
  (ref) => GoOnlineAtSpot(
    ref.watch(onlineRepositoryProvider),
    ref.watch(shiftRepositoryProvider),
    ref.watch(signalRepositoryProvider),
  ),
);
final returnToSpotUseCaseProvider = Provider((ref) => ReturnToSpot(ref.watch(shiftRepositoryProvider)));
final selectOnlineAlertUseCaseProvider = Provider((ref) => const SelectOnlineAlert());
final addShiftTimeUseCaseProvider = Provider((ref) => AddShiftTime(ref.watch(onlineRepositoryProvider)));
final startOrderUseCaseProvider = Provider((ref) => StartOrder(ref.watch(onlineRepositoryProvider)));
final takeBreakUseCaseProvider = Provider(
  (ref) => TakeBreak(ref.watch(onlineRepositoryProvider), ref.watch(clockProvider)),
);
final answerRelocationUseCaseProvider = Provider(
  (ref) => AnswerRelocation(
    ref.watch(onlineRepositoryProvider),
    ref.watch(shiftRepositoryProvider),
    ref.watch(clockProvider),
  ),
);
final findSpotsUseCaseProvider = Provider((ref) => FindSpots(ref.watch(spotChoiceRepositoryProvider)));
final confirmSpotUseCaseProvider = Provider(
  (ref) => ConfirmSpot(ref.watch(spotChoiceRepositoryProvider), ref.watch(shiftRepositoryProvider)),
);
final finishOrderUseCaseProvider = Provider((ref) => FinishOrder(ref.watch(onlineRepositoryProvider)));

final nextSpotStepUseCaseProvider = Provider((ref) => NextRouteStep(ref.watch(spotRouteRepositoryProvider)));
final watchRiderPositionUseCaseProvider = Provider((ref) => WatchDevicePosition(ref.watch(riderLocationProvider)));
