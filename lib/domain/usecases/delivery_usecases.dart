import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../core/errors/app_exception.dart';
import '../repositories/stock_repository.dart';
import '../entities/delivery_order.dart';
import '../repositories/delivery_repository.dart';
import '../../core/constants/app_patterns.dart';

/// Watches the order the rider is on.
class WatchDeliveryOrder {
  const WatchDeliveryOrder(this._repository);

  final DeliveryRepository _repository;

  Stream<DeliveryOrder?> call(String orderId) => _repository.watchOrder(orderId);
}

/// What the routing engine reports about the route; null when it is fine.
class WatchRouteIssue {
  const WatchRouteIssue(this._repository);

  final RouteIssueRepository _repository;

  Stream<RouteIssue?> call() => _repository.watch();
}

/// The 90 s clock runs from the assignment, whatever the rider is doing.
OrderClock orderClockOf(DeliveryOrder order, DateTime now) {
  final left = OrderRules.window - now.difference(order.assignedAt);
  return OrderClock(secondsLeft: math.max(0, (left.inMilliseconds / 1000).ceil()), late: left.isNegative);
}

/// What a customer's cancellation pays the rider: cash nothing (there's no
/// cancellation charge), UPI the lesser of ₹20 and the order's price.
CancellationPay cancellationPayOf(DeliveryOrder order) {
  if (order.payment == OrderPayment.cash) return const CancellationPay(CancellationKind.cash, 0);
  return order.amount >= OrderRules.upiCancellationPay
      ? const CancellationPay(CancellationKind.upiFlat, OrderRules.upiCancellationPay)
      : CancellationPay(CancellationKind.upiFull, order.amount);
}

/// The issue to show. Without signal nothing can be rerouted, so that comes
/// first; the rest is what the routing engine reports.
RouteIssue? routeIssueOf({required bool signal, RouteIssue? reported}) => signal ? reported : RouteIssue.weakSignal;

/// "Navigate to Gate 3" (Order 01 → 02).
class StartNavigation {
  const StartNavigation(this._repository);

  final DeliveryRepository _repository;

  Future<void> call(DeliveryOrder order) async {
    if (order.status == DeliveryStatus.assigned) await _repository.startNavigation(order.id);
  }
}

/// "Skip this order" → Order 04 → Submit → Order 05: only before setting off.
class SkipOrder {
  const SkipOrder(this._repository);

  final DeliveryRepository _repository;

  Future<void> call(DeliveryOrder order, SkipReason reason) async {
    if (order.status != DeliveryStatus.assigned) throw const AppException();
    await _repository.skip(order.id, reason);
  }
}

/// "I've reached the gate" (→ Arrival 01).
class ReachGate {
  const ReachGate(this._repository);

  final DeliveryRepository _repository;

  Future<void> call(DeliveryOrder order) => _repository.markReachedGate(order.id);
}

/// Arrival 01 → 03, or 02 when it isn't this gate. Location alone can't confirm
/// arrival: it takes the QR code at the gate, or the gate's code.
///
/// A gate's QR says `NZG|<gate id>`; its code is 4 digits. Anything else can't
/// be right, and doesn't go to the backend. The backend knows the right ones,
/// so this needs signal.
class ConfirmGate {
  const ConfirmGate(this._repository, this._signal);

  final DeliveryRepository _repository;
  final SignalRepository _signal;

  static final _qr = RegExp(AppPatterns.gateQr);
  static final _code = RegExp(AppPatterns.fourDigitCode);

  /// Whether the gate is confirmed.
  Future<bool> call(DeliveryOrder order, GateMethod method, String proof) async {
    final value = proof.trim();
    final valid = switch (method) {
      GateMethod.qr => _qr.hasMatch(value),
      GateMethod.code => _code.hasMatch(value),
    };
    if (!valid) return false;
    if (!await _signal.isOnline()) throw const AppException();
    return _repository.confirmGate(order.id, method, value);
  }
}

/// Shares the rider's position on the order, at most every [every]. A failed
/// update is ignored; the next position retries.
class ShareOrderLocation {
  ShareOrderLocation(this._repository, this._clock);

  static const every = Duration(seconds: 10);

  final DeliveryRepository _repository;
  final DateTime Function() _clock;
  DateTime? _last;

  void call(DeliveryOrder order, LatLng point) {
    if (order.status != DeliveryStatus.onTheWay) return;
    final now = _clock();
    final last = _last;
    if (last != null && now.difference(last) < every) return;
    _last = now;
    _repository.updateRiderLocation(order.id, point).catchError((Object _) {});
  }
}
