import '../entities/order.dart';
import '../repositories/order_repository.dart';

/// Orders ready at the kitchen and waiting for a rider. Orders older than
/// [maxAge] are treated as abandoned and left out.
class WatchOpenOrders {
  const WatchOpenOrders(this._repo, this._now);

  static const maxAge = Duration(minutes: 10);

  final OrderRepository _repo;
  final DateTime Function() _now;

  Stream<List<Order>> call() => _repo.watchOpenOrders().map((orders) {
        final cutoff = _now().subtract(maxAge);
        return orders.where((o) => o.createdAt.isAfter(cutoff)).toList();
      });
}
