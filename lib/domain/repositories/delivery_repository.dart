import 'package:latlong2/latlong.dart';

import '../entities/delivery_order.dart';
import '../entities/handover.dart';

/// The order flow's backend. The backend assigns and cancels orders; the rider
/// sets off, reaches the gate, proves it, hands over, or skips.
abstract interface class DeliveryRepository {
  /// Updates live, also when the customer cancels; null until it's known.
  Stream<DeliveryOrder?> watchOrder(String orderId);

  /// "Navigate to Gate 3" (Order 01 → 02).
  Future<void> startNavigation(String orderId);

  /// "I've reached the gate" (→ Arrival 01). Doesn't confirm anything.
  Future<void> markReachedGate(String orderId);

  /// Returns false if [proof] isn't this gate's QR code or code; riders can't
  /// read those, the backend checks.
  Future<bool> confirmGate(String orderId, GateMethod method, String proof);

  /// Order 04 → 05.
  Future<void> skip(String orderId, SkipReason reason);

  /// Marks it delivered. Returns false if the customer's code is wrong; riders
  /// can't read it, the backend checks. Can time out without a connection.
  Future<bool> completeHandover(HandoverRequest request);

  /// A handover saved on the phone (Handover 10), now that there's signal.
  Future<void> syncSavedHandover(SavedHandover saved);

  /// Handover 07: tells the customer the rider is waiting at the gate.
  Future<void> notifyCustomerWaiting(String orderId);

  /// So the customer can follow.
  Future<void> updateRiderLocation(String orderId, LatLng point);
}

/// What the routing engine reports on the way to the gate.
abstract interface class RouteIssueRepository {
  /// The current issue, null when the route is fine.
  Stream<RouteIssue?> watch();
}
