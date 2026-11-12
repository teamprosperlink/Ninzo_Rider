import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'core/constants/app_durations.dart';
import 'data/datasources/remote/google_api.dart';
import 'data/repositories/google_place_repository.dart';
import 'data/repositories/google_route_repository.dart';
import 'domain/repositories/place_repository.dart';
import 'core/constants/app_mode.dart';
import 'core/utils/clock_provider.dart';
import 'core/constants/demo_data.dart';
import 'data/repositories/demo_user_repository.dart';
import 'domain/repositories/user_repository.dart';
import 'domain/usecases/watch_user.dart';
import 'data/repositories/demo_auth_repository.dart';
import 'data/repositories/api_auth_repositories.dart';
import 'data/datasources/remote/rider_api.dart';
import 'data/datasources/remote/rider_api_client.dart';
import 'data/datasources/remote/rider_api_session.dart';
import 'data/repositories/api_delivery_repository.dart';
import 'data/repositories/api_online_repository.dart';
import 'data/repositories/api_profile_repositories.dart';
import 'data/repositories/api_route_repository.dart';
import 'data/datasources/remote/push_token_source.dart';
import 'data/datasources/remote/server_pushes.dart';
import 'data/repositories/api_shift_repository.dart';
import 'data/repositories/api_stock_repository.dart';
import 'data/repositories/prefs_session_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/rider_directory.dart';
import 'domain/repositories/session_repository.dart';
import 'domain/usecases/request_login_code.dart';
import 'domain/usecases/restore_session.dart';
import 'domain/usecases/sign_out.dart';
import 'domain/usecases/verify_otp.dart';
import 'domain/usecases/watch_auth_state.dart';
import 'data/repositories/device_permission_repository.dart';
import 'data/repositories/prefs_intro_repository.dart';
import 'domain/repositories/intro_repository.dart';
import 'domain/repositories/permission_repository.dart';
import 'domain/usecases/permission_usecases.dart';
import 'data/repositories/geolocator_location_repository.dart';
import 'domain/repositories/location_repository.dart';
import 'domain/usecases/watch_device_position.dart';
import 'data/repositories/demo_online_repository.dart';
import 'data/repositories/demo_rider_location.dart';
import 'data/repositories/spot_choice_repositories.dart';
import 'domain/repositories/online_repository.dart';
import 'domain/repositories/spot_choice_repository.dart';
import 'domain/usecases/break_usecases.dart';
import 'domain/usecases/choose_spot_usecases.dart';
import 'domain/usecases/online_usecases.dart';
import 'domain/usecases/plan_online_pushes.dart';
import 'domain/usecases/relocation_usecases.dart';
import 'domain/usecases/spot_usecases.dart';
import 'data/repositories/demo_delivery_repository.dart';
import 'data/datasources/local/local_handover_stores.dart';
import 'domain/repositories/delivery_repository.dart';
import 'domain/repositories/handover_repository.dart';
import 'domain/usecases/delivery_usecases.dart';
import 'domain/usecases/handover_usecases.dart';
import 'data/repositories/demo_profile_repository.dart';
import 'domain/repositories/profile_repository.dart';
import 'domain/usecases/profile_usecases.dart';
import 'domain/usecases/refill_usecases.dart';
import 'data/repositories/demo_registration_repository.dart';
import 'data/datasources/local/image_picker_photo_source.dart';
import 'domain/repositories/area_repository.dart';
import 'domain/repositories/photo_source.dart';
import 'domain/repositories/registration_repository.dart';
import 'domain/usecases/area_usecases.dart';
import 'domain/usecases/document_usecases.dart';
import 'domain/usecases/save_registration_details.dart';
import 'domain/usecases/start_registration.dart';
import 'data/repositories/demo_shift_repository.dart';
import 'data/repositories/device_status_repository_impl.dart';
import 'data/datasources/local/local_shift_notifier.dart';
import 'data/repositories/route_repositories.dart';
import 'domain/repositories/device_status_repository.dart';
import 'domain/repositories/route_repository.dart';
import 'domain/repositories/shift_notifier.dart';
import 'domain/repositories/shift_repository.dart';
import 'domain/usecases/home_status_of.dart';
import 'domain/usecases/plan_shift_pushes.dart';
import 'domain/usecases/route_usecases.dart';
import 'domain/usecases/shift_flow_usecases.dart';
import 'domain/usecases/shift_push_usecases.dart';
import 'domain/usecases/stock_request_usecases.dart';
import 'data/repositories/device_health_repositories.dart';
import 'data/repositories/shift_session_repositories.dart';
import 'data/repositories/sync_status_repositories.dart';
import 'domain/repositories/shift_end_repositories.dart';
import 'domain/usecases/shift_end_usecases.dart';
import 'data/repositories/demo_stock_repository.dart';
import 'data/datasources/local/local_stock_stores.dart';
import 'data/repositories/signal_repositories.dart';
import 'data/datasources/local/app_launch.dart';
import 'domain/repositories/stock_repository.dart';
import 'domain/usecases/signal_usecases.dart';
import 'domain/usecases/stock_usecases.dart';

// ---- account ----

final riderApiProvider = Provider((ref) => RiderApi(RiderApiClient()));

/// The rider API's live state (`--dart-define=RIDER_API=true`), shared by its
/// repositories: the shift, offers, orders, stock and restock follow the
/// backend's flow, and the phone's GPS goes to it while a shift is open.
final riderApiSessionProvider = Provider((ref) {
  final session = RiderApiSession(ref.watch(riderApiProvider), clock: ref.watch(clockProvider));
  ref.onDispose(session.dispose);
  return session;
});

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => kRiderApi
      ? ApiUserRepository(ref.watch(riderApiProvider))
      : kDemoMode
      ? DemoUserRepository()
      : ApiUserRepository(ref.watch(riderApiProvider)),
);

final watchUserUseCaseProvider = Provider((ref) => WatchUser(ref.watch(userRepositoryProvider)));

// ---- auth ----

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (kDemoMode && !kRiderApi) return DemoAuthRepository();
  final api = ApiAuthRepository(ref.watch(riderApiProvider), push: const FirebasePushTokenSource());
  ref.onDispose(api.dispose);
  return api;
});

final riderDirectoryProvider = Provider<RiderDirectory>(
  (ref) => kRiderApi
      ? const ApiRiderDirectory()
      : kDemoMode
      ? DemoRiderDirectory()
      : const ApiRiderDirectory(),
);

final sessionRepositoryProvider = Provider<SessionRepository>((ref) => PrefsSessionRepository());

final watchAuthStateUseCaseProvider = Provider((ref) => WatchAuthState(ref.watch(authRepositoryProvider)));
final requestLoginCodeUseCaseProvider = Provider(
  (ref) => RequestLoginCode(ref.watch(authRepositoryProvider), ref.watch(riderDirectoryProvider)),
);
final verifyOtpUseCaseProvider = Provider(
  (ref) => VerifyOtp(ref.watch(authRepositoryProvider), ref.watch(sessionRepositoryProvider)),
);
final signOutUseCaseProvider = Provider(
  (ref) => SignOut(ref.watch(authRepositoryProvider), ref.watch(sessionRepositoryProvider)),
);
final restoreSessionUseCaseProvider = Provider(
  (ref) => RestoreSession(ref.watch(authRepositoryProvider), ref.watch(sessionRepositoryProvider)),
);

// ---- intro ----

/// Permissions are the phone's own, so demo mode uses the real ones too.
final permissionRepositoryProvider = Provider<PermissionRepository>((ref) => DevicePermissionRepository());
final introRepositoryProvider = Provider<IntroRepository>((ref) => PrefsIntroRepository());

final requestPermissionUseCaseProvider = Provider((ref) => RequestPermission(ref.watch(permissionRepositoryProvider)));
final checkPermissionUseCaseProvider = Provider((ref) => CheckPermission(ref.watch(permissionRepositoryProvider)));
final openPermissionSettingsUseCaseProvider = Provider(
  (ref) => OpenPermissionSettings(ref.watch(permissionRepositoryProvider)),
);
final permissionsIntroUseCaseProvider = Provider((ref) => PermissionsIntro(ref.watch(introRepositoryProvider)));

/// How long the splash stays up at least, from the tap that opened the app.
final splashDurationProvider = Provider((ref) => AppDurations.splash);

/// How long ago the app was started.
final timeSinceAppStartProvider = Provider<Future<Duration> Function()>((ref) => timeSinceAppStart);

// ---- location ----

final locationRepositoryProvider = Provider<LocationRepository>((ref) => GeolocatorLocationRepository());

final watchDevicePositionUseCaseProvider =
    Provider((ref) => WatchDevicePosition(ref.watch(locationRepositoryProvider)));

// ---- online ----

final onlineRepositoryProvider = Provider<OnlineRepository>((ref) {
  if (kRiderApi || !kDemoMode) return ApiOnlineRepository(ref.watch(riderApiSessionProvider));
  final demo = DemoOnlineRepository(ref.watch(clockProvider));
  ref.onDispose(demo.dispose);
  return demo;
});

/// The rider's position around the spot. Demo: simulated, about 1.2 km away.
final riderLocationProvider = Provider<LocationRepository>((ref) {
  // The rider API follows the phone's own GPS.
  if (!kDemoMode || kRiderApi) return ref.watch(locationRepositoryProvider);
  final demo = DemoRiderLocation(kDemoSimulatedRider ? null : ref.watch(locationRepositoryProvider));
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

/// Choose a spot (Shift 13–18). Only the demo has spots to choose from; the
/// rider API assigns the node.
final spotChoiceRepositoryProvider = Provider<SpotChoiceRepository>(
  (ref) => kDemoMode && !kRiderApi ? DemoSpotChoiceRepository() : const NoSpotChoices(),
);

/// Plays the backend on Choose a spot; null outside demo mode.
final demoSpotChoiceProvider = Provider<DemoSpotChoiceRepository?>((ref) {
  final repository = ref.watch(spotChoiceRepositoryProvider);
  return repository is DemoSpotChoiceRepository ? repository : null;
});

final spotRouteRepositoryProvider = Provider<RouteRepository>(
  (ref) => kDemoSimulatedRider ? const DemoSpotRouteRepository() : ref.watch(googleRouteRepositoryProvider),
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


// ── The order flow (Figma Sections 11–13) ──

/// Plays the orders in demo mode; null otherwise.
final demoDeliveryProvider = Provider<DemoDeliveryRepository?>((ref) {
  if (!kDemoMode || kRiderApi) return null;
  final demo = DemoDeliveryRepository(
    ref.watch(clockProvider),
    ref.watch(onlineRepositoryProvider) as DemoOnlineRepository,
    ref.watch(riderLocationProvider) as DemoRiderLocation,
    ref.watch(demoSignalProvider),
  );
  ref.onDispose(demo.dispose);
  return demo;
});

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => kRiderApi
      ? ApiDeliveryRepository(ref.watch(riderApiSessionProvider))
      : ref.watch(demoDeliveryProvider) ?? ApiDeliveryRepository(ref.watch(riderApiSessionProvider)),
);

final routeIssueRepositoryProvider = Provider<RouteIssueRepository>(
  (ref) => ref.watch(demoDeliveryProvider) ?? const NoRouteIssues(),
);

/// The next turn on the way to the gate. Demo: the design's sample turns.
final orderRouteRepositoryProvider = Provider<RouteRepository>(
  (ref) => kDemoSimulatedRider
      ? const DemoOrderRouteRepository()
      : kRiderApi
      ? GoogleRouteRepository(
          ref.watch(googleApiProvider),
          fallback: ApiRouteRepository(ref.watch(riderApiSessionProvider)),
        )
      : ref.watch(googleRouteRepositoryProvider),
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
  (ref) => kDemoMode && !kRiderApi ? InMemoryHandoverStore() : PrefsHandoverStore(),
);

final problemReportRepositoryProvider = Provider<ProblemReportRepository>(
  (ref) => kRiderApi
      ? ApiProblemReportRepository(ref.watch(riderApiSessionProvider))
      : kDemoMode
      ? DemoProblemReportRepository()
      : ApiProblemReportRepository(ref.watch(riderApiSessionProvider)),
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
  (ref) => StartNextOrder(
    ref.watch(onlineRepositoryProvider),
    ref.watch(deliveryRepositoryProvider),
    packFirst: kRiderApi,
  ),
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

// ---- profile ----

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => kRiderApi
      ? ApiProfileRepository(ref.watch(riderApiSessionProvider))
      : kDemoMode
      ? DemoProfileRepository(ref.watch(clockProvider))
      : ApiProfileRepository(ref.watch(riderApiSessionProvider)),
);

final watchProfileFactsUseCaseProvider = Provider((ref) => WatchProfileFacts(ref.watch(profileRepositoryProvider)));
final watchRiderNotificationsUseCaseProvider = Provider(
  (ref) => WatchRiderNotifications(ref.watch(profileRepositoryProvider)),
);
final watchShiftRecordsUseCaseProvider = Provider((ref) => WatchShiftRecords(ref.watch(profileRepositoryProvider)));

// ---- refill ----

final startRefillUseCaseProvider = Provider(
  (ref) => StartRefill(ref.watch(shiftRepositoryProvider), ref.watch(stockRepositoryProvider)),
);
final cancelRefillUseCaseProvider = Provider((ref) => CancelRefill(ref.watch(shiftRepositoryProvider)));
final finishRefillUseCaseProvider = Provider(
  (ref) => FinishRefill(ref.watch(shiftRepositoryProvider), ref.watch(onlineRepositoryProvider)),
);
final answerRestockUseCaseProvider = Provider(
  (ref) => AnswerRestock(ref.watch(onlineRepositoryProvider), ref.watch(startRefillUseCaseProvider)),
);

// ---- register ----

final registrationRepositoryProvider = Provider<RegistrationRepository>(
  (ref) => kRiderApi
      ? ApiRegistrationRepository(ref.watch(riderApiSessionProvider))
      : kDemoMode
      ? DemoRegistrationRepository()
      : ApiRegistrationRepository(ref.watch(riderApiSessionProvider)),
);

final areaRepositoryProvider = Provider<AreaRepository>(
  (ref) => kRiderApi
      ? const ApiAreaRepository()
      : kDemoMode
      ? DemoAreaRepository()
      : const ApiAreaRepository(),
);

final photoSourceProvider = Provider<PhotoSource>(
  (ref) => ImagePickerPhotoSource(),
);

final watchRegistrationUseCaseProvider = Provider(
  (ref) => WatchRegistration(ref.watch(registrationRepositoryProvider)),
);
final startRegistrationUseCaseProvider = Provider(
  (ref) => StartRegistration(
    ref.watch(riderDirectoryProvider),
    ref.watch(authRepositoryProvider),
  ),
);
final saveRegistrationDetailsUseCaseProvider = Provider(
  (ref) => SaveRegistrationDetails(
    ref.watch(registrationRepositoryProvider),
    ref.watch(userRepositoryProvider),
  ),
);
final googleApiProvider = Provider((ref) => GoogleApi());
final googleRouteRepositoryProvider = Provider<RouteRepository>((ref) => GoogleRouteRepository(ref.watch(googleApiProvider)));
final placeRepositoryProvider = Provider<PlaceRepository>((ref) => GooglePlaceRepository(ref.watch(googleApiProvider)));
final searchAreasUseCaseProvider = Provider(
  (ref) => SearchAreas(ref.watch(areaRepositoryProvider), ref.watch(placeRepositoryProvider)),
);
final resolveAreaUseCaseProvider = Provider((ref) => ResolveArea(ref.watch(placeRepositoryProvider)));
final findAreaNearMeUseCaseProvider = Provider(
  (ref) => FindAreaNearMe(ref.watch(placeRepositoryProvider), ref.watch(locationRepositoryProvider)),
);
final takeDocumentPhotoUseCaseProvider = Provider(
  (ref) => TakeDocumentPhoto(ref.watch(photoSourceProvider)),
);
final uploadDocumentPhotoUseCaseProvider = Provider(
  (ref) => UploadDocumentPhoto(ref.watch(registrationRepositoryProvider)),
);
final submitForReviewUseCaseProvider = Provider(
  (ref) => SubmitForReview(ref.watch(registrationRepositoryProvider)),
);
final reopenApplicationUseCaseProvider = Provider(
  (ref) => ReopenApplication(ref.watch(registrationRepositoryProvider)),
);
final acknowledgeApprovalUseCaseProvider = Provider(
  (ref) => AcknowledgeApproval(ref.watch(registrationRepositoryProvider)),
);

// ---- shift ----

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  if (kRiderApi || !kDemoMode) return ApiShiftRepository(ref.watch(riderApiSessionProvider));
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
  (ref) => kDemoSimulatedRider ? const DemoRouteRepository(DemoData.hubDistanceKm) : ref.watch(googleRouteRepositoryProvider),
);

/// The rider's position on the way to the hub. Demo: a fixed point about
/// 1.2 km from the sample hub (emulators sit far away).
final tripPositionSourceProvider = Provider<Stream<LatLng> Function()>((ref) {
  if (kDemoSimulatedRider) return () => Stream.value(const LatLng(DemoData.riderLat, DemoData.riderLng));
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

/// The rider API sends its own pushes; demo and tests have none.
final serverPushesProvider = Provider<ServerPushes>(
  (ref) => kRiderApi ? const FcmServerPushes(FirebasePushTokenSource()) : const NoServerPushes(),
);
final watchServerPushesUseCaseProvider = Provider((ref) => WatchServerPushes(ref.watch(serverPushesProvider)));
final cancelPushUseCaseProvider = Provider((ref) => CancelPush(ref.watch(shiftNotifierProvider)));

// ---- shift_end ----

final deviceHealthRepositoryProvider = Provider<DeviceHealthRepository>(
  (ref) => kDemoMode && !kRiderApi
      ? DemoDeviceHealthRepository()
      : PhoneDeviceHealthRepository(ref.watch(deviceStatusRepositoryProvider)),
);

final shiftSessionRepositoryProvider = Provider<ShiftSessionRepository>(
  (ref) => kRiderApi
      ? ApiShiftSessionRepository(ref.watch(riderApiSessionProvider))
      : kDemoMode
      ? DemoShiftSessionRepository()
      : ApiShiftSessionRepository(ref.watch(riderApiSessionProvider)),
);

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  final local = LocalSyncStatusRepository(ref.watch(handoverStoreProvider), ref.watch(syncSavedHandoversUseCaseProvider));
  if (!kDemoMode || kRiderApi) return local;
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

// ---- stock ----

/// Scans whole lots on the rider API; null otherwise.
final apiStockRepositoryProvider = Provider<ApiStockRepository?>(
  (ref) => kRiderApi ? ApiStockRepository(ref.watch(riderApiSessionProvider)) : null,
);

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) =>
      ref.watch(apiStockRepositoryProvider) ??
      DemoStockRepository(ref.watch(clockProvider)),
);

final stockScanStoreProvider = Provider<StockScanStore>(
  (ref) => kDemoMode && !kRiderApi ? InMemoryStockScanStore() : PrefsStockScanStore(),
);

final signalRepositoryProvider = Provider<SignalRepository>((ref) {
  if (!kDemoMode || kRiderApi) return ConnectivitySignalRepository();
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
    ref.watch(apiStockRepositoryProvider),
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
