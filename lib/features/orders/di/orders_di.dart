import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_mode.dart';
import '../../../core/di/clock_provider.dart';
import '../../../core/di/firebase_providers.dart';
import '../../online/data/repositories/demo_online_repository.dart';
import '../../online/data/repositories/demo_rider_location.dart';
import '../../online/di/online_di.dart';
import '../../shift/data/repositories/route_repositories.dart';
import '../../shift/domain/repositories/route_repository.dart';
import '../../shift/domain/usecases/route_usecases.dart';
import '../../stock/di/stock_di.dart';
import '../data/repositories/demo_delivery_repository.dart';
import '../data/repositories/demo_order_repository.dart';
import '../data/repositories/firestore_delivery_repository.dart';
import '../data/repositories/firestore_order_repository.dart';
import '../data/repositories/local_handover_stores.dart';
import '../domain/repositories/delivery_repository.dart';
import '../domain/repositories/handover_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/usecases/accept_order.dart';
import '../domain/usecases/deliver_order.dart';
import '../domain/usecases/delivery_usecases.dart';
import '../domain/usecases/handover_usecases.dart';
import '../domain/usecases/rank_offers.dart';
import '../domain/usecases/watch_delivery_history.dart';
import '../domain/usecases/watch_open_orders.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  if (!kDemoMode) return FirestoreOrderRepository(ref.watch(firestoreProvider));
  final demo = DemoOrderRepository();
  ref.onDispose(demo.dispose);
  return demo;
});

final watchOpenOrdersUseCaseProvider =
    Provider((ref) => WatchOpenOrders(ref.watch(orderRepositoryProvider), ref.watch(clockProvider)));
final rankOffersUseCaseProvider = Provider((ref) => const RankOffers());
final watchDeliveryHistoryUseCaseProvider =
    Provider((ref) => WatchDeliveryHistory(ref.watch(orderRepositoryProvider)));
final acceptOrderUseCaseProvider = Provider((ref) => AcceptOrder(ref.watch(orderRepositoryProvider)));
final deliverOrderUseCaseProvider = Provider((ref) => DeliverOrder(ref.watch(orderRepositoryProvider)));

// ── The order flow (Figma Sections 11–13) ──

/// Plays the orders in demo mode; null otherwise.
final demoDeliveryProvider = Provider<DemoDeliveryRepository?>((ref) {
  if (!kDemoMode) return null;
  final demo = DemoDeliveryRepository(
    ref.watch(clockProvider),
    ref.watch(onlineRepositoryProvider) as DemoOnlineRepository,
    ref.watch(riderLocationProvider) as DemoRiderLocation,
    ref.watch(demoSignalProvider),
    ref.watch(orderRepositoryProvider) as DemoOrderRepository,
  );
  ref.onDispose(demo.dispose);
  return demo;
});

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => ref.watch(demoDeliveryProvider) ?? FirestoreDeliveryRepository(ref.watch(firestoreProvider)),
);

final routeIssueRepositoryProvider = Provider<RouteIssueRepository>(
  (ref) => ref.watch(demoDeliveryProvider) ?? const NoRouteIssues(),
);

/// The next turn on the way to the gate. Demo: the design's sample turns.
final orderRouteRepositoryProvider = Provider<RouteRepository>(
  (ref) => kDemoMode ? const DemoOrderRouteRepository() : const StraightLineRouteRepository(),
);

final watchDeliveryOrderUseCaseProvider = Provider((ref) => WatchDeliveryOrder(ref.watch(deliveryRepositoryProvider)));
final startNavigationUseCaseProvider = Provider((ref) => StartNavigation(ref.watch(deliveryRepositoryProvider)));
final skipOrderUseCaseProvider = Provider((ref) => SkipOrder(ref.watch(deliveryRepositoryProvider)));
final reachGateUseCaseProvider = Provider((ref) => ReachGate(ref.watch(deliveryRepositoryProvider)));
final confirmGateUseCaseProvider = Provider(
  (ref) => ConfirmGate(ref.watch(deliveryRepositoryProvider), ref.watch(signalRepositoryProvider)),
);
final shareOrderLocationUseCaseProvider = Provider(
  (ref) => ShareOrderLocation(ref.watch(deliveryRepositoryProvider), ref.watch(clockProvider)),
);

// ── Handover and problem report (Figma Sections 14–15) ──

/// Saved handovers stay on the phone; the demo's day starts afresh on each
/// launch, so its copy does too.
final handoverStoreProvider = Provider<HandoverStore>(
  (ref) => kDemoMode ? InMemoryHandoverStore() : PrefsHandoverStore(),
);

final problemReportRepositoryProvider = Provider<ProblemReportRepository>(
  (ref) => kDemoMode ? DemoProblemReportRepository() : FirestoreProblemReportRepository(ref.watch(firestoreProvider)),
);

final completeHandoverUseCaseProvider = Provider(
  (ref) => CompleteHandover(
    ref.watch(deliveryRepositoryProvider),
    ref.watch(handoverStoreProvider),
    ref.watch(signalRepositoryProvider),
    ref.watch(clockProvider),
  ),
);
final saveQuantitiesUseCaseProvider = Provider(
  (ref) => SaveQuantities(ref.watch(handoverStoreProvider), ref.watch(signalRepositoryProvider), ref.watch(clockProvider)),
);
final loadHandoverLocalUseCaseProvider = Provider((ref) => LoadHandoverLocal(ref.watch(handoverStoreProvider)));
final forgetSavedHandoverUseCaseProvider = Provider((ref) => ForgetSavedHandover(ref.watch(handoverStoreProvider)));
final syncSavedHandoversUseCaseProvider = Provider(
  (ref) => SyncSavedHandovers(
    ref.watch(deliveryRepositoryProvider),
    ref.watch(handoverStoreProvider),
    ref.watch(clockProvider),
  ),
);
final finishSavedHandoverUseCaseProvider = Provider(
  (ref) => FinishSavedHandover(
    ref.watch(handoverStoreProvider),
    ref.watch(onlineRepositoryProvider),
    ref.watch(syncSavedHandoversUseCaseProvider),
    ref.watch(signalRepositoryProvider),
  ),
);
final startNextOrderUseCaseProvider = Provider(
  (ref) => StartNextOrder(ref.watch(onlineRepositoryProvider), ref.watch(deliveryRepositoryProvider)),
);
final notifyCustomerWaitingUseCaseProvider = Provider(
  (ref) => NotifyCustomerWaiting(ref.watch(deliveryRepositoryProvider)),
);
final sendProblemReportUseCaseProvider = Provider(
  (ref) => SendProblemReport(
    ref.watch(problemReportRepositoryProvider),
    ref.watch(signalRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

final nextGateStepUseCaseProvider = Provider((ref) => NextRouteStep(ref.watch(orderRouteRepositoryProvider)));
final watchRouteIssueUseCaseProvider = Provider((ref) => WatchRouteIssue(ref.watch(routeIssueRepositoryProvider)));
