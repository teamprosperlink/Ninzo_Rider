// Firestore has its own Order (index sort order) class.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../../../../core/error/firebase_error_mapper.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/delivery_order_model.dart';
import '../models/order_model.dart';

/// Orders live in `orders/{id}` and are created by the customer side (or
/// backend) with status `ready`. The customer's delivery code lives in
/// `orders/{id}/private/code`, which riders can't read. firestore.rules
/// enforces every status change and stamps the pickup and delivery times.
class FirestoreOrderRepository implements OrderRepository {
  FirestoreOrderRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  @override
  Stream<List<Order>> watchOpenOrders() => _orders
      .where('status', isEqualTo: OrderStatus.ready.name)
      .where('riderId', isNull: true)
      .snapshots()
      .map((s) => _newestFirst(s.docs));

  @override
  Stream<List<Order>> watchHistory(String riderId) => _orders
      .where('riderId', isEqualTo: riderId)
      .snapshots()
      .map(
        (s) => <Order>[
          for (final d in s.docs)
            if (d.data()['status'] == OrderStatus.delivered.name)
              // The new order flow's deliveries have no restaurant.
              d.data()['restaurant'] == null ? DeliveryOrderModel.historyOrder(d.id, d.data()) : OrderModel.fromFirestore(d),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<bool> acceptOrder(String orderId, {required String riderId, required RiderInfo rider}) async {
    try {
      return await _db.runTransaction((tx) async {
        final snap = await tx.get(_orders.doc(orderId));
        final j = snap.data();
        if (j?['status'] != OrderStatus.ready.name || j?['riderId'] != null) return false;
        tx.update(snap.reference, {
          'status': OrderStatus.accepted.name,
          'riderId': riderId,
          'rider': OrderModel.riderToFirestore(rider),
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } on FirebaseException catch (e) {
      // Once another rider takes the order, this rider may no longer read it.
      if (e.code == 'permission-denied' || e.code == 'not-found') return false;
      throw firebaseError(e);
    }
  }

  @override
  Future<bool> markDelivered(String orderId, String code) async {
    try {
      await _update(orderId, {
        'status': OrderStatus.delivered.name,
        'deliveryCode': code,
        'deliveredAt': FieldValue.serverTimestamp(),
      }, guard: false);
      return true;
    } on FirebaseException catch (e) {
      // The security rules reject a wrong code.
      if (e.code == 'permission-denied') return false;
      throw firebaseError(e);
    }
  }

  Future<void> _update(String orderId, Map<String, Object?> data, {bool guard = true}) {
    Future<void> call() => _orders.doc(orderId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    return guard ? guardFirebase(call) : call();
  }

  static List<Order> _newestFirst(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) =>
      docs.map(OrderModel.fromFirestore).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
