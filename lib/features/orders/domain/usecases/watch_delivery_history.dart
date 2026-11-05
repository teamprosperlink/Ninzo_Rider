import '../entities/order.dart';
import '../repositories/order_repository.dart';

/// Delivered orders, newest first.
class WatchDeliveryHistory {
  const WatchDeliveryHistory(this._repo);

  final OrderRepository _repo;

  Stream<List<Order>> call(String riderId) => _repo.watchHistory(riderId);
}
