import '../entities/order.dart';

/// The offers (on hold) and the delivery history. Figma's order flow is
/// DeliveryRepository.
abstract interface class OrderRepository {
  /// Orders ready at the kitchen and waiting for a rider.
  Stream<List<Order>> watchOpenOrders();

  /// Delivered orders, newest first.
  Stream<List<Order>> watchHistory(String riderId);

  /// Returns false if another rider took the order or it was cancelled first.
  Future<bool> acceptOrder(String orderId, {required String riderId, required RiderInfo rider});

  /// Returns false if [code] does not match the customer's delivery code.
  Future<bool> markDelivered(String orderId, String code);
}
