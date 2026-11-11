import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/presentation/app/views/app.dart';
import 'package:ninzo_rider/domain/entities/auth_failure.dart';
import 'package:ninzo_rider/domain/entities/rider_account_info.dart';
import 'package:ninzo_rider/domain/repositories/rider_directory.dart';
import 'package:ninzo_rider/domain/repositories/session_repository.dart';
import 'package:ninzo_rider/injection_container.dart';
import 'package:ninzo_rider/domain/entities/app_permission.dart';
import 'package:ninzo_rider/domain/repositories/intro_repository.dart';
import 'package:ninzo_rider/domain/repositories/permission_repository.dart';
import 'package:ninzo_rider/domain/entities/app_user.dart';
import 'package:ninzo_rider/domain/entities/auth_user.dart';
import 'package:ninzo_rider/domain/entities/otp_request.dart';
import 'package:ninzo_rider/data/repositories/demo_delivery_repository.dart';
import 'package:ninzo_rider/domain/entities/delivery_order.dart';
import 'package:ninzo_rider/data/datasources/local/local_handover_stores.dart';
import 'package:ninzo_rider/domain/entities/handover.dart';
import 'package:ninzo_rider/domain/entities/problem_report.dart';
import 'package:ninzo_rider/domain/repositories/handover_repository.dart';
import 'package:ninzo_rider/domain/entities/order.dart';
import 'package:ninzo_rider/domain/repositories/delivery_repository.dart';
import 'package:ninzo_rider/presentation/orders/widgets/gate_scanner.dart';
import 'package:ninzo_rider/domain/repositories/auth_repository.dart';
import 'package:ninzo_rider/domain/repositories/location_repository.dart';
import 'package:ninzo_rider/core/utils/clock_provider.dart';
import 'package:ninzo_rider/domain/entities/profile.dart';
import 'package:ninzo_rider/domain/repositories/profile_repository.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/rider_area.dart';
import 'package:ninzo_rider/domain/entities/rider_document.dart';
import 'package:ninzo_rider/domain/repositories/area_repository.dart';
import 'package:ninzo_rider/domain/repositories/place_repository.dart';
import 'package:ninzo_rider/domain/repositories/photo_source.dart';
import 'package:ninzo_rider/domain/repositories/registration_repository.dart';
import 'package:ninzo_rider/domain/repositories/user_repository.dart';
import 'package:ninzo_rider/data/repositories/route_repositories.dart';
import 'package:ninzo_rider/core/errors/app_exception.dart';
import 'package:ninzo_rider/data/repositories/demo_rider_location.dart';
import 'package:ninzo_rider/domain/entities/online_status.dart';
import 'package:ninzo_rider/domain/entities/spot_option.dart';
import 'package:ninzo_rider/domain/repositories/online_repository.dart';
import 'package:ninzo_rider/domain/repositories/spot_choice_repository.dart';
import 'package:ninzo_rider/domain/entities/restock.dart';
import 'package:ninzo_rider/domain/entities/shift_end.dart';
import 'package:ninzo_rider/domain/repositories/shift_end_repositories.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';
import 'package:ninzo_rider/domain/entities/shift_push.dart';
import 'package:ninzo_rider/domain/repositories/device_status_repository.dart';
import 'package:ninzo_rider/domain/repositories/shift_notifier.dart';
import 'package:ninzo_rider/domain/repositories/shift_repository.dart';
import 'package:ninzo_rider/domain/usecases/plan_shift_pushes.dart';
import 'package:ninzo_rider/data/datasources/local/local_stock_stores.dart';
import 'package:ninzo_rider/domain/entities/stock.dart';
import 'package:ninzo_rider/domain/repositories/stock_repository.dart';
import 'package:ninzo_rider/presentation/stock/widgets/stock_scanner.dart';

/// A value whose stream emits the current value, then every change.
class Watched<T> {
  Watched(this._value);

  T _value;
  final _changes = StreamController<T>.broadcast();

  T get value => _value;

  set value(T v) {
    _value = v;
    _changes.add(v);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _changes.stream;
  }
}

const testOtp = '123456';
const riderPoint = LatLng(28.6139, 77.2090);

class FakeAuthRepository implements AuthRepository {
  final user = Watched<AuthUser?>(null);
  String? _phone;

  /// When set, the next sendOtp waits for it (Login 15 "Sending code").
  Completer<void>? sendGate;

  /// When set, the next verifyOtp waits for it (Login 07 "Verifying").
  Completer<void>? verifyGate;

  /// Thrown by the next verifyOtp (then cleared), whatever the code.
  AuthFailureKind? nextVerifyFailure;

  @override
  Stream<AuthUser?> authStateChanges() => user.stream;

  @override
  Future<OtpRequest> sendOtp(String phoneNumber, {int? resendToken}) async {
    final gate = sendGate;
    sendGate = null;
    if (gate != null) await gate.future;
    _phone = phoneNumber;
    return const OtpRequest(verificationId: 'verification-1');
  }

  @override
  Future<void> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    final gate = verifyGate;
    verifyGate = null;
    if (gate != null) await gate.future;
    final failure = nextVerifyFailure;
    nextVerifyFailure = null;
    if (failure != null) throw AuthFailure(failure);
    if (code != testOtp) throw const AuthFailure(AuthFailureKind.wrongCode);
    user.value = AuthUser(uid: 'u1', phone: _phone!);
  }

  @override
  Future<void> signInNewRider(String phoneNumber) async =>
      user.value = AuthUser(uid: 'u1', phone: phoneNumber);

  @override
  Future<void> signOut() async => user.value = null;
}

/// Rider accounts by number; every number is a rider unless [result] says
/// otherwise.
class FakeRiderDirectory implements RiderDirectory {
  RiderAccountInfo? result = const RiderAccountInfo(
    hubLabel: 'Hub 2 · Yelahanka',
    shiftStart: '11:00 AM',
  );

  /// Thrown instead of answering (e.g. no internet).
  AuthFailureKind? failure;

  @override
  Future<RiderAccountInfo?> find(String phoneNumber) async {
    if (failure case final kind?) throw AuthFailure(kind);
    return result;
  }
}

class FakeSessionRepository implements SessionRepository {
  bool keep = true;
  bool was = false;

  @override
  Future<bool> keepSignedIn() async => keep;

  @override
  Future<void> setKeepSignedIn(bool value) async => keep = value;

  @override
  Future<bool> wasSignedIn() async => was;

  @override
  Future<void> setWasSignedIn(bool value) async => was = value;
}

class FakeIntroRepository implements IntroRepository {
  FakeIntroRepository({this.seen = true});

  bool seen;

  @override
  Future<bool> permissionsSeen() async => seen;

  @override
  Future<void> markPermissionsSeen() async => seen = true;
}

class FakePermissionRepository implements PermissionRepository {
  /// What each permission currently is; requests grant unless [denyRequests].
  final status = {
    for (final p in AppPermission.values) p: PermissionResult.denied,
  };
  bool denyRequests = false;
  final opened = <AppPermission>[];

  @override
  Future<PermissionResult> check(AppPermission permission) async =>
      status[permission]!;

  @override
  Future<PermissionResult> request(AppPermission permission) async {
    if (!denyRequests) status[permission] = PermissionResult.granted;
    return status[permission]!;
  }

  @override
  Future<void> openSettings(AppPermission permission) async =>
      opened.add(permission);
}

class FakeUserRepository implements UserRepository {
  final user = Watched<AppUser?>(null);

  @override
  Stream<AppUser?> watchUser(String uid) => user.stream;

  @override
  Future<void> createUser(AppUser u) async => user.value = u;

  @override
  Future<void> updateProfile(
    String uid, {
    required String name,
    String? email,
  }) async {
    final u = user.value!;
    user.value = AppUser(uid: u.uid, phone: u.phone, name: name, email: email);
  }
}

/// The rider's application, following the same steps the security rules
/// allow; the test plays the review team by setting [application].
class FakeRegistrationRepository implements RegistrationRepository {
  final application = Watched<RiderApplication?>(null);

  /// Phone numbers listed in the rider directory by [saveDetails].
  final listed = <String>[];

  /// When set, the next upload waits for it.
  Completer<void>? uploadGate;

  RiderApplication get _a => application.value!;

  /// Listens for changes before the first value, so a save right after
  /// signing in isn't lost (as with Firestore snapshots).
  @override
  Stream<RiderApplication?> watch(String uid) async* {
    final changes = StreamController<RiderApplication?>();
    final subscription = application._changes.stream.listen(changes.add);
    try {
      yield application.value;
      yield* changes.stream;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> saveDetails({
    required String uid,
    required String phone,
    required String name,
    required RiderArea area,
  }) async {
    application.value =
        application.value?.copyWith(name: name, area: area) ??
        // The backend maps the area to a hub.
        RiderApplication(
          uid: uid,
          name: name,
          phone: phone,
          area: area,
          hubLabel: 'Hub 2 · Yelahanka',
        );
    listed.add(phone);
  }

  @override
  Future<String> uploadPhoto({
    required String uid,
    required RiderDocument document,
    required DocumentSide side,
    required String filePath,
  }) async {
    final gate = uploadGate;
    uploadGate = null;
    if (gate != null) await gate.future;
    return 'https://example.com/$uid/${document.name}_${side.name}.jpg';
  }

  @override
  Future<void> saveDocuments(
    String uid,
    Map<RiderDocument, DocumentUpload> documents,
  ) async => application.value = _a.copyWith(documents: documents);

  @override
  Future<void> reopen(String uid) async =>
      application.value = _a.copyWith(status: RegistrationStatus.draft);

  @override
  Future<void> submit(String uid) async => application.value = _a.copyWith(
    status: RegistrationStatus.underReview,
    submittedAt: DateTime.now(),
  );

  @override
  Future<void> markWelcomed(String uid) async =>
      application.value = _a.copyWith(welcomed: true);
}

const testAreas = [
  RiderArea(
    id: 'yelahanka',
    name: 'Yelahanka',
    city: 'Bengaluru',
    popular: true,
    latitude: 13.1007,
    longitude: 77.5963,
  ),
  RiderArea(
    id: 'bagalur',
    name: 'Bagalur',
    city: 'Bengaluru',
    popular: true,
    latitude: 13.1333,
    longitude: 77.6667,
  ),
  RiderArea(
    id: 'jakkur',
    name: 'Jakkur',
    city: 'Bengaluru',
    popular: true,
    latitude: 13.0786,
    longitude: 77.6060,
  ),
  RiderArea(
    id: 'hebbal',
    name: 'Hebbal',
    city: 'Bengaluru',
    popular: true,
    latitude: 13.0358,
    longitude: 77.5970,
  ),
  RiderArea(
    id: 'devanahalli',
    name: 'Devanahalli',
    city: 'Bengaluru',
    popular: true,
    latitude: 13.2437,
    longitude: 77.7172,
  ),
  RiderArea(
    id: 'kogilu',
    name: 'Kogilu',
    city: 'Bengaluru',
    popular: true,
    latitude: 13.1046,
    longitude: 77.6150,
  ),
  RiderArea(
    id: 'ynt',
    name: 'Yelahanka New Town',
    city: 'Bengaluru',
    latitude: 13.1004,
    longitude: 77.5770,
  ),
  RiderArea(
    id: 'yot',
    name: 'Yelahanka Old Town',
    city: 'Bengaluru',
    latitude: 13.0950,
    longitude: 77.5960,
  ),
  RiderArea(
    id: 'yst',
    name: 'Yelahanka Satellite Town',
    city: 'Bengaluru',
    latitude: 13.0840,
    longitude: 77.5850,
  ),
];

class FakeAreaRepository implements AreaRepository {
  @override
  Future<List<RiderArea>> all() async => testAreas;
}

/// Stands in for Google: finds [testAreas] by name.
class FakePlaceRepository implements PlaceRepository {
  @override
  Future<List<RiderArea>> search(String query) async {
    final q = query.toLowerCase();
    return testAreas.where((a) => a.name.toLowerCase().contains(q)).toList();
  }

  @override
  Future<RiderArea> details(RiderArea area) async => area;

  @override
  Future<RiderArea?> near(LatLng point) async {
    const distance = Distance();
    RiderArea? best;
    var bestKm = 25.0;
    for (final area in testAreas) {
      final km = distance.as(LengthUnit.Kilometer, point, LatLng(area.latitude!, area.longitude!));
      if (km <= bestKm) {
        best = area;
        bestKm = km;
      }
    }
    return best;
  }
}

/// Hands back [path] instead of opening the camera (null = cancelled).
class FakePhotoSource implements PhotoSource {
  String? path = '/nonexistent/photo.jpg';
  final taken = <bool>[];

  /// When set, the camera or gallery stays open until the test completes it
  /// with the photo path (or null for cancel), like the real system apps.
  Completer<String?>? open;

  Future<String?> _pick() {
    final gate = open;
    open = null;
    return gate?.future ?? Future.value(path);
  }

  @override
  Future<String?> takePhoto({bool selfie = false}) {
    taken.add(selfie);
    return _pick();
  }

  @override
  Future<String?> pickFromGallery() => _pick();
}

/// The order A2931 at Gate 3, as on the designs.
DeliveryOrder testDeliveryOrder({
  DateTime? assignedAt,
  DeliveryStatus status = DeliveryStatus.assigned,
  OrderPayment payment = OrderPayment.upi,
  int amount = 60,
  LatLng gatePoint = testGatePoint,
  DateTime? gateConfirmedAt,
}) => DeliveryOrder(
  id: 'A2931',
  number: 'A2931',
  gate: DeliveryGate(name: 'Gate 3', landmark: 'Main entrance', point: gatePoint),
  items: const [
    OrderItem(name: 'Smash Burger', quantity: 2),
    OrderItem(name: 'Paneer Tikka Wrap', quantity: 1),
  ],
  payment: payment,
  amount: amount,
  assignedAt: assignedAt ?? DateTime(2026, 1, 1, 10),
  status: status,
  customerPhone: '+918000000000',
  riderFee: 40,
  tripMeters: 600,
  gateConfirmedAt: gateConfirmedAt,
);

const testGatePoint = LatLng(13.11, 77.59);
const testGateQr = 'NZG|gate-3';
const testGateCode = '4821';

/// The customer's code on a UPI order; riders never see it.
const testCustomerCode = '4829';

/// The order the rider is on; the test plays the backend by setting [order].
class FakeDeliveryRepository implements DeliveryRepository, RouteIssueRepository {
  final order = Watched<DeliveryOrder?>(null);
  final issue = Watched<RouteIssue?>(null);
  final shared = <LatLng>[];
  int reachedGate = 0;

  /// When set, the next handover waits for it (Handover 05).
  Completer<void>? handoverGate;
  final handovers = <HandoverRequest>[];
  final synced = <SavedHandover>[];
  int customerNotified = 0;
  bool failSync = false;

  /// What the backend does on delivery.
  void Function(HandoverRequest request)? onDelivered;

  @override
  Stream<DeliveryOrder?> watchOrder(String orderId) => order.stream;

  @override
  Future<void> startNavigation(String orderId) async =>
      order.value = order.value!.copyWith(status: DeliveryStatus.onTheWay);

  @override
  Future<void> markReachedGate(String orderId) async => reachedGate++;

  @override
  Future<bool> confirmGate(String orderId, GateMethod method, String proof) async {
    final right = proof == (method == GateMethod.qr ? testGateQr : testGateCode);
    if (right) {
      final current = order.value!;
      order.value = current.copyWith(
        status: DeliveryStatus.atGate,
        gateConfirmedAt: current.assignedAt.add(const Duration(seconds: 72)),
      );
    }
    return right;
  }

  @override
  Future<bool> completeHandover(HandoverRequest request) async {
    final gate = handoverGate;
    handoverGate = null;
    if (gate != null) await gate.future;
    if (request.proof == HandoverProof.code && request.code != testCustomerCode) return false;
    handovers.add(request);
    onDelivered?.call(request);
    order.value = order.value!.copyWith(status: DeliveryStatus.delivered);
    return true;
  }

  @override
  Future<void> syncSavedHandover(SavedHandover saved) async {
    if (failSync) throw StateError('no signal');
    synced.add(saved);
  }

  @override
  Future<void> notifyCustomerWaiting(String orderId) async => customerNotified++;

  @override
  Future<void> skip(String orderId, SkipReason reason) async =>
      order.value = order.value!.copyWith(status: DeliveryStatus.skipped, skipReason: reason);

  @override
  Future<void> updateRiderLocation(String orderId, LatLng point) async => shared.add(point);

  @override
  Stream<RouteIssue?> watch() => issue.stream;
}

class FakeLocationRepository implements LocationRepository {
  @override
  Future<LatLng> currentPosition() async => riderPoint;

  @override
  Stream<LatLng> positionStream() => Stream.value(riderPoint);
}

const hubPoint = LatLng(13.1007, 77.5963);

/// About 1.2 km from [hubPoint], as on Shift 52.
const nearHubPoint = LatLng(13.0928, 77.5895);

/// Today's shift as in the Figma designs: 9:00 AM at Hub 2, Yelahanka Node,
/// scooter KA 01 AB 1234, 4 items / 6 portions; stock not requested yet.
Shift testShift({
  StockRequestStatus stockRequest = StockRequestStatus.notRequested,
  ShiftPhase phase = ShiftPhase.notStarted,
  int scanned = 0,
  DateTime? stockReadyAt,
}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, 9);
  return Shift(
    id: Shift.idFor(now),
    start: start,
    end: start.add(const Duration(hours: 4)),
    hub: const Hub(id: 'hub-2', name: 'Hub 2', area: 'Yelahanka', point: hubPoint),
    spot: const Spot(name: 'Yelahanka Node', point: LatLng(13.1052, 77.5921)),
    scooter: const Scooter(plate: 'KA 01 AB 1234', batteryPercent: 82),
    stockRequest: stockRequest,
    stockReadyAt: stockReadyAt,
    phase: phase,
    stock: StockLoad(items: 4, portions: 6, scanned: scanned),
    hubDistanceKm: 1.2,
  );
}

/// The rider around the spot; the test moves them by setting [position].
class FakeRiderLocation implements LocationRepository {
  final position = Watched<LatLng>(const LatLng(13.0968, 77.5853));

  /// When set, the next location check waits for it (Shift 24).
  Completer<void>? gate;

  /// The location check fails (the phone can't tell).
  bool unavailable = false;

  @override
  Future<LatLng> currentPosition() async {
    final g = gate;
    gate = null;
    if (g != null) await g.future;
    if (unavailable) throw const AppException('No location');
    return position.value;
  }

  @override
  Stream<LatLng> positionStream() => position.stream;
}

/// The online rider's backend; the test plays it by setting [status].
class FakeOnlineRepository implements OnlineRepository {
  final status = Watched<OnlineStatus>(const OnlineStatus());

  /// When set, the next Add time waits for it (Shift 34).
  Completer<void>? gate;
  AssignedOrder? started;

  @override
  Stream<OnlineStatus> watch(String uid, String shiftId) => status.stream;

  @override
  Future<void> setBreak(String uid, String shiftId, BreakState? state) async =>
      status.value = status.value.copyWith(breakState: () => state);

  @override
  Future<void> setNudge(String uid, String shiftId, RelocationNudge? nudge) async =>
      status.value = status.value.copyWith(nudge: () => nudge);

  @override
  Future<void> setRestock(String uid, String shiftId, RestockRequest? restock) async =>
      status.value = status.value.copyWith(restock: () => restock);

  @override
  Future<void> addStock(String uid, String shiftId, int portions) async =>
      status.value = status.value.copyWith(stockAdded: status.value.stockAdded + portions);

  @override
  Future<void> markOnline(String uid, String shiftId) async =>
      status.value = status.value.copyWith(onlineAt: DateTime.now());

  @override
  Future<void> setShiftEnd(String uid, String shiftId, DateTime end) async {
    final g = gate;
    gate = null;
    if (g != null) await g.future;
    status.value = status.value.copyWith(shiftEnd: () => end);
  }

  @override
  Future<void> startOrder(String uid, String shiftId, AssignedOrder order) async {
    started = order;
    status.value = status.value.copyWith(activeOrderId: () => order.id);
  }

  @override
  Future<void> finishOrder(String uid, String shiftId, String orderId, {String? thenStart}) async =>
      status.value = status.value.copyWith(
        queue: status.value.queue.where((o) => o.id != orderId).toList(),
        activeOrderId: () => thenStart,
      );
}

/// Today's shift; the test plays the backend (hub packing) by setting
/// [shift].
/// Shift 14's spots. Hold a search or a claim with [findGate], [claimGate].
class FakeSpotChoices implements SpotChoiceRepository {
  List<SpotOption> spots = const [
    SpotOption(name: 'Hebbal Node', km: 2.4, taken: 3, capacity: 3, point: LatLng(13.1188, 77.5788)),
    SpotOption(name: 'Jakkur Node', km: 0.9, taken: 0, capacity: 3, point: LatLng(13.1095, 77.5960)),
    SpotOption(name: 'Yelahanka Node', km: 1.2, taken: 1, capacity: 3, point: LatLng(13.1052, 77.5921)),
  ];
  Completer<void>? findGate;
  Completer<void>? claimGate;
  bool failFind = false;
  bool failClaim = false;

  /// Names another rider got to first.
  final taken = <String>{};
  final claims = <String>[];

  @override
  Future<List<SpotOption>> nearbySpots(String uid) async {
    await findGate?.future;
    if (failFind) throw Exception('no signal');
    return spots;
  }

  @override
  Future<bool> claimSpot(String uid, String shiftId, SpotOption spot) async {
    await claimGate?.future;
    if (failClaim) throw Exception('no signal');
    claims.add(spot.name);
    return !taken.contains(spot.name);
  }
}

class FakeShiftRepository implements ShiftRepository {
  final shift = Watched<Shift?>(testShift());

  Shift get _s => shift.value!;

  @override
  Future<void> setRefill(
    String uid,
    String shiftId, {
    required RefillLoad? refill,
    required int round,
    required ShiftPhase phase,
  }) async => shift.value = _s.copyWith(refill: () => refill, refillRound: round, phase: phase);

  @override
  Future<void> setSpot(String uid, String shiftId, Spot spot) async => shift.value = _s.copyWith(spot: spot);

  @override
  Stream<Shift?> watchToday(String uid) => shift.stream;

  @override
  Future<void> replyToStockRequest(String uid, String shiftId, StockRequestStatus reply) async =>
      shift.value = _s.copyWith(stockRequest: reply);

  /// When set, the next setPhase waits for it (Shift 06 "Starting…").
  Completer<void>? phaseGate;

  @override
  Future<void> setPhase(String uid, String shiftId, ShiftPhase phase) async {
    final gate = phaseGate;
    phaseGate = null;
    if (gate != null) await gate.future;
    shift.value = _s.copyWith(phase: phase);
  }

  @override
  Future<void> recordScans(String uid, String shiftId, int scanned) async =>
      shift.value = _s.copyWith(stock: _s.stock.copyWith(scanned: scanned));
}

/// The Figma sample load: 4 items, 6 portions.
const testStockManifest = StockManifest(
  items: [
    StockItem(id: 'smash', name: 'Smash Burger', quantity: 2, image: 'assets/images/stock_smash_burger.jpg'),
    StockItem(id: 'paneer', name: 'Paneer Tikka Wrap', quantity: 2, image: 'assets/images/stock_paneer_tikka_wrap.jpg'),
    StockItem(id: 'fries', name: 'Peri Peri Fries', quantity: 1, image: 'assets/images/stock_peri_peri_fries.jpg'),
    StockItem(id: 'coffee', name: 'Cold Coffee', quantity: 1, image: 'assets/images/stock_cold_coffee.jpg'),
  ],
);

/// A label for portion [n] of an item.
String testCode(String itemId, int n, [String lot = 'A-1']) => 'NZ1|$itemId|$lot|$n';

class FakeStockRepository implements StockRepository {
  StockManifest load = testStockManifest;
  final lots = <String, StockLot>{};
  final uploaded = <StockScan>[];
  final quarantined = <String>[];

  @override
  Future<void> prepareLoad(String uid, String shiftId, List<StockItem> items) async => prepared[shiftId] = items;

  /// What restocks asked the hub to pack, by load.
  final prepared = <String, List<StockItem>>{};

  /// While set, lot checks wait for it (Stock 12 "Checking item…").
  Completer<void>? lotGate;

  /// Calls fail, as without signal.
  bool failing = false;

  void _check() {
    if (failing) throw StateError('no signal');
  }

  @override
  Future<StockManifest> manifest(String uid, String shiftId) async {
    _check();
    final asked = prepared[shiftId];
    return asked == null ? load : StockManifest(items: asked);
  }

  @override
  Future<List<StockScan>> uploadedScans(String uid, String shiftId) async {
    _check();
    return List.of(uploaded);
  }

  @override
  Future<StockLot?> lot(String uid, String shiftId, String lotId) async {
    _check();
    await lotGate?.future;
    return lots[lotId];
  }

  @override
  Future<void> uploadScans(String uid, String shiftId, List<StockScan> scans) async {
    _check();
    uploaded.addAll(scans.map((s) => s.asSynced));
  }

  @override
  Future<void> moveToQuarantine(String uid, String shiftId, QuarantineRequest request) async {
    _check();
    quarantined.add(request.lotId);
  }
}

class FakeSignal implements SignalRepository {
  bool _online = true;
  final _changes = StreamController<bool>.broadcast();

  bool get online => _online;

  set online(bool value) {
    _online = value;
    _changes.add(value);
  }

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> watchOnline() => _changes.stream;
}

/// Problem reports the rider sent.
class FakeProblemReports implements ProblemReportRepository {
  final sent = <ProblemReport>[];

  @override
  Future<void> send(ProblemReport report) async => sent.add(report);
}

/// Stands in for the camera: [read] is a QR code coming into view.
class FakeScanner {
  ValueChanged<String>? _onCode;
  VoidCallback? _onUnavailable;

  void read(String code) => _onCode?.call(code);

  void fail() => _onUnavailable?.call();

  Widget build(BuildContext context, ValueChanged<String> onCode, VoidCallback onUnavailable) {
    _onCode = onCode;
    _onUnavailable = onUnavailable;
    return const SizedBox.shrink();
  }
}

/// The rider's records behind Profile 04–07.
class FakeProfileRepository implements ProfileRepository {
  final facts = Watched<ProfileFacts>(const ProfileFacts());
  final notifications = Watched<List<RiderNotification>>(const []);
  final shifts = Watched<List<ShiftRecord>>(const []);

  @override
  Stream<ProfileFacts> watchFacts(String uid) => facts.stream;

  @override
  Stream<List<RiderNotification>> watchNotifications(String uid) => notifications.stream;

  @override
  Stream<List<ShiftRecord>> watchShifts(String uid) => shifts.stream;
}

/// Records the pushes instead of showing them.
class FakeShiftNotifier implements ShiftNotifier {
  final scheduled = <ShiftPush, DateTime>{};
  final shown = <ShiftPush>[];
  final cancelled = <ShiftPush>[];
  final _actions = StreamController<ShiftPushAction>.broadcast();
  final shownDetail = <ShiftPush, PushDetail>{};
  final _opened = StreamController<ShiftPush>.broadcast();

  /// The rider taps [push] itself.
  void open(ShiftPush push) => _opened.add(push);

  @override
  Stream<ShiftPush> get opened => _opened.stream;

  @override
  ShiftPush? get launchedFrom => null;

  /// The rider taps [action] on a push.
  void tap(ShiftPushAction action) => _actions.add(action);

  @override
  Future<ShiftPushAction?> init() async => null;

  @override
  Future<void> schedule(ShiftPush push, Shift shift, DateTime at) async => scheduled[push] = at;

  @override
  Future<void> show(ShiftPush push, Shift shift, {PushDetail detail = const PushDetail()}) async {
    shown.add(push);
    shownDetail[push] = detail;
  }

  @override
  Future<void> cancel(ShiftPush push) async {
    scheduled.remove(push);
    cancelled.add(push);
  }

  @override
  Stream<ShiftPushAction> get actions => _actions.stream;
}

/// The phone's location and clock (Shift 41, 42).
class FakeDeviceHealth implements DeviceHealthRepository {
  bool location = true;
  bool autoTime = true;
  int locationOpened = 0;
  int dateOpened = 0;

  @override
  Future<bool> locationOn() async => location;

  @override
  Future<bool> phoneTimeAutomatic() async => autoTime;

  @override
  Future<void> openLocationSettings() async => locationOpened++;

  @override
  Future<void> openDateSettings() async => dateOpened++;
}

/// Which phone holds the shift (Shift 54).
class FakeShiftSessions implements ShiftSessionRepository {
  bool otherPhone = false;
  int claims = 0;
  int ended = 0;

  @override
  Future<bool> openElsewhere(String uid, String shiftId) async => otherPhone;

  @override
  Future<void> claim(String uid, String shiftId) async {
    otherPhone = false;
    claims++;
  }

  @override
  Future<void> markEnded(String uid, String shiftId) async => ended++;
}

/// What waits for signal (Shift 40, Sync 01).
class FakeSyncStatus implements SyncStatusRepository {
  SyncSnapshot snapshot = const SyncSnapshot();
  int retries = 0;

  @override
  Future<SyncSnapshot> load(String uid) async => snapshot;

  @override
  Future<void> retry(String uid) async => retries++;
}

class FakeDeviceStatus implements DeviceStatusRepository {
  int battery = 80;
  bool location = true;
  int settingsOpened = 0;

  @override
  Future<int> phoneBattery() async => battery;

  @override
  Future<bool> locationOn() async => location;

  @override
  Future<void> openLocationSettings() async => settingsOpened++;
}

class Fakes {
  final auth = FakeAuthRepository();
  final directory = FakeRiderDirectory();
  final session = FakeSessionRepository();
  final intro = FakeIntroRepository();
  final permissions = FakePermissionRepository();

  /// How long the splash stays up.
  Duration splash = Duration.zero;
  final users = FakeUserRepository();
  final registration = FakeRegistrationRepository();
  final photos = FakePhotoSource();
  final delivery = FakeDeliveryRepository();
  final problemReports = FakeProblemReports();

  /// Where saved handovers go; a test may use the real one.
  HandoverStore handoverStore = InMemoryHandoverStore();
  final gateScanner = FakeScanner();

  /// Added to the real time the app sees. Fake test time doesn't move
  /// DateTime.now(), so tests move this instead.
  Duration clockOffset = Duration.zero;

  /// When set, the time the app sees (e.g. 9:41 for the Figma frames).
  DateTime? now;

  final shifts = FakeShiftRepository();
  final online = FakeOnlineRepository();
  final spotChoices = FakeSpotChoices();
  final riderLocation = FakeRiderLocation();
  final notifier = FakeShiftNotifier();
  final device = FakeDeviceStatus();
  final deviceHealth = FakeDeviceHealth();
  final shiftSessions = FakeShiftSessions();
  final syncStatus = FakeSyncStatus();
  final profile = FakeProfileRepository();
  final stock = FakeStockRepository();
  final signal = FakeSignal();
  final scanner = FakeScanner();

  /// Where scans are saved; a test may use the real one.
  StockScanStore stockStore = InMemoryStockScanStore();

  /// The rider's position on the way to the hub.
  final tripPosition = Watched<LatLng>(nearHubPoint);

  /// Signs in a rider; with [status] they also have an application (an
  /// approved one is welcomed, so the app opens on Home).
  void signIn({RegistrationStatus? status}) {
    auth.user.value = const AuthUser(uid: 'u1', phone: '+919876543210');
    users.user.value = const AppUser(
      uid: 'u1',
      phone: '+919876543210',
      name: 'Aman',
    );
    if (status != null) {
      registration.application.value = riderApplication(status);
    }
  }

  /// A complete application in [status].
  RiderApplication riderApplication(
    RegistrationStatus status, {
    String name = 'Aman',
  }) => RiderApplication(
    uid: 'u1',
    name: name,
    phone: '+919876543210',
    area: testAreas.first,
    status: status,
    documents: {
      for (final d in RiderDocument.values)
        d: DocumentUpload(
          files: {
            for (final side in d.sides)
              side: 'https://example.com/${d.name}_${side.name}.jpg',
          },
        ),
    },
    hubLabel: 'Hub 2 · Yelahanka',
    firstShift: 'Tomorrow, 11:00 AM – 3:00 PM',
    spotName: 'Yelahanka Node',
    spotDistanceKm: 1.2,
    welcomed: status == RegistrationStatus.approved,
  );
}

Future<Fakes> pumpApp(WidgetTester tester, [Fakes? fakes]) async {
  final f = fakes ??= Fakes();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(
          () => f.now ?? DateTime.now().add(f.clockOffset),
        ),
        shiftRepositoryProvider.overrideWithValue(fakes.shifts),
        onlineRepositoryProvider.overrideWithValue(fakes.online),
        spotChoiceRepositoryProvider.overrideWithValue(fakes.spotChoices),
        riderLocationProvider.overrideWithValue(fakes.riderLocation),
        spotRouteRepositoryProvider.overrideWithValue(const DemoSpotRouteRepository()),
        stockRepositoryProvider.overrideWithValue(fakes.stock),
        stockScanStoreProvider.overrideWithValue(fakes.stockStore),
        signalRepositoryProvider.overrideWithValue(fakes.signal),
        stockScannerProvider.overrideWithValue(fakes.scanner.build),
        deliveryRepositoryProvider.overrideWithValue(fakes.delivery),
        routeIssueRepositoryProvider.overrideWithValue(fakes.delivery),
        handoverStoreProvider.overrideWithValue(fakes.handoverStore),
        problemReportRepositoryProvider.overrideWithValue(fakes.problemReports),
        orderRouteRepositoryProvider.overrideWithValue(const DemoOrderRouteRepository()),
        gateScannerProvider.overrideWithValue(fakes.gateScanner.build),
        shiftNotifierProvider.overrideWithValue(fakes.notifier),
        deviceStatusRepositoryProvider.overrideWithValue(fakes.device),
        deviceHealthRepositoryProvider.overrideWithValue(fakes.deviceHealth),
        shiftSessionRepositoryProvider.overrideWithValue(fakes.shiftSessions),
        syncStatusRepositoryProvider.overrideWithValue(fakes.syncStatus),
        profileRepositoryProvider.overrideWithValue(fakes.profile),
        pushTimesProvider.overrideWithValue(const ShiftPushTimes()),
        routeRepositoryProvider.overrideWithValue(const DemoRouteRepository(1.2)),
        tripPositionSourceProvider.overrideWithValue(() => f.tripPosition.stream),
        authRepositoryProvider.overrideWithValue(fakes.auth),
        riderDirectoryProvider.overrideWithValue(fakes.directory),
        sessionRepositoryProvider.overrideWithValue(fakes.session),
        introRepositoryProvider.overrideWithValue(fakes.intro),
        permissionRepositoryProvider.overrideWithValue(fakes.permissions),
        splashDurationProvider.overrideWithValue(fakes.splash),
        // No Android process to ask in a test.
        timeSinceAppStartProvider.overrideWithValue(() async => Duration.zero),
        userRepositoryProvider.overrideWithValue(fakes.users),
        registrationRepositoryProvider.overrideWithValue(fakes.registration),
        areaRepositoryProvider.overrideWithValue(FakeAreaRepository()),
        placeRepositoryProvider.overrideWithValue(FakePlaceRepository()),
        photoSourceProvider.overrideWithValue(fakes.photos),
        locationRepositoryProvider.overrideWithValue(FakeLocationRepository()),
      ],
      child: const NinzoRiderApp(),
    ),
  );
  await settle(tester);
  return fakes;
}

/// Lets streams deliver. pumpAndSettle can't be used: progress
/// indicators animate forever.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
