import '../../../../core/error/app_exception.dart';
import '../entities/order.dart';
import '../repositories/order_repository.dart';

/// Hands the order over. The customer's 4-digit code proves it arrived.
class DeliverOrder {
  const DeliverOrder(this._repo);

  final OrderRepository _repo;

  Future<void> call(Order order, String code) async {
    final trimmed = code.trim();
    if (trimmed.length != 4) throw const AppException();
    final ok = await _repo.markDelivered(order.id, trimmed);
    if (!ok) throw const AppException();
  }
}
