import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/error/firebase_error_mapper.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/entities/handover.dart';
import '../../domain/entities/order.dart' show OrderItem;
import '../../domain/entities/problem_report.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../../domain/repositories/handover_repository.dart';
import '../models/delivery_order_model.dart';

/// Reads and moves `orders/{id}` (see [DeliveryOrderModel]); firestore.rules
/// enforces every step and checks the gate's QR code or code.
///
/// TODO(backend): create the orders, tell the customer the rider is nearly
/// there once the 90 s are over, reassign skipped orders, and on a cancellation
/// set `cancelled` and pay the trip (`cancellationPayOf`); on delivery update
/// `today` and `stock.sold` from `handedOver`, take the order out of `queue`,
/// and review the handovers without a checked code (`details`, `offline`,
/// `handoverCode`). Limit how many wrong codes a rider can try per order.
class FirestoreDeliveryRepository implements DeliveryRepository {
  FirestoreDeliveryRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String id) => _db.collection('orders').doc(id);

  Future<void> _update(String id, Map<String, Object> data) =>
      guardFirebase(() => _doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()}));

  @override
  Stream<DeliveryOrder?> watchOrder(String orderId) => _doc(orderId).snapshots().map((s) {
    final j = s.data();
    return j == null ? null : DeliveryOrderModel.fromFirestore(s.id, j);
  });

  @override
  Future<void> startNavigation(String orderId) =>
      _update(orderId, {'status': DeliveryStatus.onTheWay.name, 'navigatingAt': FieldValue.serverTimestamp()});

  @override
  Future<void> markReachedGate(String orderId) => _update(orderId, {'reachedGateAt': FieldValue.serverTimestamp()});

  @override
  Future<bool> confirmGate(String orderId, GateMethod method, String proof) async {
    try {
      await _doc(orderId).update({
        'status': DeliveryStatus.atGate.name,
        'gateMethod': method.name,
        'gateProof': proof,
        'gateConfirmedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      // The security rules reject a wrong QR code or code.
      if (e.code == 'permission-denied') return false;
      throw firebaseError(e);
    }
  }

  @override
  Future<void> skip(String orderId, SkipReason reason) => _update(orderId, {
    'status': DeliveryStatus.skipped.name,
    'skipReason': reason.name,
    'skippedAt': FieldValue.serverTimestamp(),
  });

  /// Firestore waits for a connection for ever; the rider can't.
  static const _handoverTimeout = Duration(seconds: 12);

  static List<Map<String, Object>> _items(List<OrderItem> items) => [
    for (final item in items) {'name': item.name, 'qty': item.quantity},
  ];

  @override
  Future<bool> completeHandover(HandoverRequest request) async {
    try {
      await _doc(request.orderId)
          .update({
            'status': DeliveryStatus.delivered.name,
            'handoverMethod': request.proof.name,
            'deliveryCode': ?request.code,
            'handedOver': _items(request.items),
            'deliveredAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_handoverTimeout);
      return true;
    } on FirebaseException catch (e) {
      // The security rules reject a wrong code.
      if (e.code == 'permission-denied' && request.proof == HandoverProof.code) return false;
      throw firebaseError(e);
    }
  }

  @override
  Future<void> syncSavedHandover(SavedHandover saved) async {
    try {
      await _doc(saved.orderId)
          .update({
            'status': DeliveryStatus.delivered.name,
            'handoverMethod': 'offline',
            'offlineProof': saved.proof.name,
            'handoverCode': ?saved.code,
            'handedOver': _items(saved.items),
            'handedOverAt': Timestamp.fromDate(saved.savedAt),
            'deliveredAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_handoverTimeout);
    } on FirebaseException catch (e) {
      // Already delivered: an earlier write got through after all.
      if (e.code == 'permission-denied') return;
      throw firebaseError(e);
    }
  }

  @override
  Future<void> notifyCustomerWaiting(String orderId) =>
      _update(orderId, {'customerWaitingAt': FieldValue.serverTimestamp()});

  @override
  Future<void> updateRiderLocation(String orderId, LatLng point) =>
      _update(orderId, {'riderLocation': GeoPoint(point.latitude, point.longitude)});
}

/// `problemReports/{id}`.
///
/// TODO(backend): pick the reports up, answer on the order ("we'll update you
/// right here"), and don't penalise the rider for it.
class FirestoreProblemReportRepository implements ProblemReportRepository {
  FirestoreProblemReportRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> send(ProblemReport report) => guardFirebase(
    () => _db.collection('problemReports').add({
      'riderId': report.riderId,
      if (report.orderId != null) 'orderId': report.orderId,
      'kind': report.kind.name,
      'createdAt': FieldValue.serverTimestamp(),
    }),
  );
}

/// No routing service yet, so nothing to report.
///
/// TODO(routing): report road closures and leaving the route from a directions
/// API (Mapbox / OSRM).
class NoRouteIssues implements RouteIssueRepository {
  const NoRouteIssues();

  @override
  Stream<RouteIssue?> watch() => Stream.value(null);
}
