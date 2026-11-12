import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../core/constants/demo_data.dart';
import 'demo_online_repository.dart';
import 'demo_rider_location.dart';
import '../../domain/repositories/route_repository.dart';
import 'signal_repositories.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/entities/handover.dart';
import '../../domain/entities/order.dart' show OrderItem;
import '../../domain/entities/problem_report.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../../domain/repositories/handover_repository.dart';
import '../../core/constants/app_strings.dart';

/// The demo's orders, built from the online queue when started. The simulated
/// rider rides to the gate on short timers; the 90 s clock stays real unless a
/// demo pill shortens it.
class DemoDeliveryRepository implements DeliveryRepository, RouteIssueRepository {
  DemoDeliveryRepository(this._clock, this._online, this._location, this._signal) {
    // The ride back is skipped: "Back to your spot" lands on Shift 26, as the
    // flow map draws it.
    _online.onOrderFinished = () {
      _rideTimer?.cancel();
      _orders.clear();
      _report(null);
      _signal?.online = true;
      _location.moveTo(DemoData.riderAtSpotMeters);
    };
  }

  final DateTime Function() _clock;
  final DemoOnlineRepository _online;
  final DemoRiderLocation _location;
  final DemoSignalRepository? _signal;

  final _orders = <String, DeliveryOrder>{};
  final _changes = StreamController<DeliveryOrder>.broadcast();
  final _issues = StreamController<RouteIssue?>.broadcast();
  Timer? _rideTimer;
  RouteIssue? _issue;
  int _scans = 0;

  static const _distance = Distance();

  DeliveryOrder? _build(String orderId) {
    final queued = _online.status.queue.where((o) => o.id == orderId).firstOrNull;
    final detail = DemoData.orderDetails[orderId];
    if (queued == null || detail == null) return null;
    final (landmark, items, upiAmount) = detail;
    final cash = queued.collectCash;
    return DeliveryOrder(
      id: orderId,
      number: queued.number,
      gate: DeliveryGate(name: queued.gate, landmark: landmark, point: _gatePoint),
      items: [for (final (name, quantity) in items) OrderItem(name: name, quantity: quantity)],
      payment: cash == null ? OrderPayment.upi : OrderPayment.cash,
      amount: cash ?? upiAmount,
      assignedAt: queued.assignedAt ?? _clock(),
      customerPhone: DemoData.customerProxyPhone,
      riderFee: DemoData.orderEarns.toInt(),
      tripMeters: DemoData.gateFromRiderMeters,
    );
  }

  /// 600 m from the spot, up-left of it as drawn on Order 01.
  LatLng get _gatePoint => DemoData.revaOrder
      ? const LatLng(DemoData.revaLat, DemoData.revaLng)
      : _distance.offset(_spot, DemoData.gateFromRiderMeters, DemoData.gateBearings.first + 180);

  LatLng get _spot => _distance.offset(
    const LatLng(DemoData.spotLat, DemoData.spotLng),
    DemoData.riderAtSpotMeters,
    DemoData.riderBearing,
  );

  /// The rider this far from the gate, where the design draws them.
  void _rideTo(int leg) => _location.moveToPoint(
    _distance.offset(_gatePoint, DemoData.gateLegMeters[leg], DemoData.gateBearings[leg]),
  );

  void _set(DeliveryOrder order) {
    _orders[order.id] = order;
    _changes.add(order);
  }

  @override
  Stream<DeliveryOrder?> watchOrder(String orderId) async* {
    final order = _orders[orderId] ?? _build(orderId);
    if (order != null) _orders[orderId] = order;
    yield order;
    yield* _changes.stream.where((o) => o.id == orderId);
  }

  @override
  Future<void> startNavigation(String orderId) async {
    // The next order of the queue starts here (Handover 11).
    final order = _orders[orderId] ?? _build(orderId);
    if (order == null) return;
    _set(order.copyWith(status: DeliveryStatus.onTheWay));
    _rideTo(1);
    _rideTimer?.cancel();
    _rideTimer = Timer(DemoData.orderRideLeg, () => _rideTo(2));
  }

  @override
  Future<void> markReachedGate(String orderId) async {
    _rideTimer?.cancel();
    _location.moveToPoint(_distance.offset(_gatePoint, DemoData.atGateMeters, DemoData.gateBearings.last));
    _signal?.online = true;
    _scans = 0;
  }

  @override
  Future<bool> confirmGate(String orderId, GateMethod method, String proof) async {
    final right = switch (method) {
      GateMethod.qr => proof == DemoData.gateQr,
      GateMethod.code => proof == DemoData.gateCode,
    };
    if (!right) return false;
    _location.moveToPoint(_distance.offset(_gatePoint, DemoData.confirmedAtGateMeters, DemoData.gateBearings.last));
    _set(_orders[orderId]!.copyWith(status: DeliveryStatus.atGate, gateConfirmedAt: _clock()));
    return true;
  }

  @override
  Future<bool> completeHandover(HandoverRequest request) async {
    // "Confirming…" (Handover 05) stays up this long.
    await Future<void>.delayed(DemoData.codeCheck);
    if (request.proof == HandoverProof.code && request.code != DemoData.deliveryCode) return false;
    final order = _orders[request.orderId]!;
    _count(SavedHandover.of(order, proof: request.proof, items: request.items, at: _clock()));
    _set(order.copyWith(status: DeliveryStatus.delivered));
    return true;
  }

  @override
  Future<void> syncSavedHandover(SavedHandover saved) async => _count(saved);

  /// What the backend does on delivery: the stats and the stock.
  void _count(SavedHandover handed) {
    _online.countDelivered(handed.portions, handed.riderFee.toDouble());
  }

  @override
  Future<void> notifyCustomerWaiting(String orderId) async {}

  @override
  Future<void> skip(String orderId, SkipReason reason) async =>
      _set(_orders[orderId]!.copyWith(status: DeliveryStatus.skipped, skipReason: reason));

  @override
  Future<void> updateRiderLocation(String orderId, LatLng point) async {}

  @override
  Stream<RouteIssue?> watch() async* {
    yield _issue;
    yield* _issues.stream;
  }

  // ── What the demo pills play ──

  /// What each tap on the viewfinder "scans": first another gate's QR, then
  /// this gate's.
  String nextScan() => _scans++ == 0 ? DemoData.wrongGateQr : DemoData.gateQr;

  void _report(RouteIssue? issue) {
    _issue = issue;
    _issues.add(issue);
  }

  /// Navigate 01–03, or back on route (null). The rider stays 0.3 km away, as
  /// on those frames.
  void playRouteIssue(RouteIssue? issue) {
    _rideTimer?.cancel();
    _rideTo(1);
    _signal?.online = issue != RouteIssue.weakSignal;
    _report(issue == RouteIssue.weakSignal ? null : issue);
  }

  /// Order 03: moves the clock past the 90 s.
  void playLate(String orderId) {
    _rideTimer?.cancel();
    _rideTo(2);
    _report(null);
    _signal?.online = true;
    _set(_orders[orderId]!.copyWith(assignedAt: _clock().subtract(OrderRules.window + const Duration(seconds: 5))));
  }

  /// Navigate 04–06: the customer cancels this [payment] order worth [amount].
  /// The food stays on the scooter; only the trip pay is counted.
  void playCancel(String orderId, OrderPayment payment, int amount, int tripPay) {
    _rideTimer?.cancel();
    _report(null);
    _signal?.online = true;
    // The demo plays the backend: the cancellation's pay lands on the order, as order_earnings would.
    _set(_orders[orderId]!.copyWith(status: DeliveryStatus.cancelled, payment: payment, amount: amount, riderFee: tripPay));
    _online.addTripPay(tripPay);
  }

  /// Handover 11 → 06: the rest of the queue goes to other riders.
  void playNoMoreOrders(String orderId) =>
      _online.set(_online.status.copyWith(queue: _online.status.queue.where((o) => o.id == orderId).toList()));

  void dispose() {
    _rideTimer?.cancel();
    _changes.close();
    _issues.close();
  }
}

/// Problem reports go nowhere in the demo.
class DemoProblemReportRepository implements ProblemReportRepository {
  final sent = <ProblemReport>[];

  @override
  Future<void> send(ProblemReport report) async {
    await Future<void>.delayed(DemoData.reportSending);
    sent.add(report);
  }
}

/// The design's sample turns (Order 01–03) by how far the gate still is.
class DemoOrderRouteRepository implements RouteRepository {
  const DemoOrderRouteRepository();

  @override
  Future<RouteStep> nextStep(LatLng from, LatLng to) async {
    final meters = const Distance().as(LengthUnit.Meter, from, to);
    if (meters > 450) {
      // Order 01 says "turn left" under the right-turn arrow; kept as drawn.
      return RouteStep(
        instruction: AppStrings.in300MTurnLeft,
        street: AppStrings.ontoChurchRoad,
        maneuver: AppStrings.headOut,
        totalKm: meters / 1000,
      );
    }
    final left = meters <= 150;
    return RouteStep(
      instruction: left ? AppStrings.in40MTurnLeft : AppStrings.in120MTurnRight,
      street: left ? AppStrings.ontoGate3Road : AppStrings.onto2ndCross,
      maneuver: left ? AppStrings.turnLeft : AppStrings.turnRight,
      totalKm: meters / 1000,
    );
  }
}
