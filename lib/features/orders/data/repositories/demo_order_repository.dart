import 'dart:async';

import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

/// Demo mode has no offers (on hold). Its orders are in DemoDeliveryRepository,
/// which adds what's delivered to the history here.
class DemoOrderRepository implements OrderRepository {
  final _history = <Order>[];
  final _changes = StreamController<List<Order>>.broadcast();

  void addDelivered(Order order) {
    _history.insert(0, order);
    _changes.add(List.of(_history));
  }

  void dispose() => _changes.close();

  @override
  Stream<List<Order>> watchOpenOrders() => Stream.value(const []);

  @override
  Stream<List<Order>> watchHistory(String riderId) async* {
    yield List.of(_history);
    yield* _changes.stream;
  }

  @override
  Future<bool> acceptOrder(String orderId, {required String riderId, required RiderInfo rider}) async => false;

  @override
  Future<bool> markDelivered(String orderId, String code) async => false;
}
