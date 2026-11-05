import '../../../../core/error/app_exception.dart';
import '../../../register/domain/entities/rider_application.dart';
import '../entities/order.dart';
import '../repositories/order_repository.dart';

/// Assigns an open order to [rider]. Fails if another rider was faster.
class AcceptOrder {
  const AcceptOrder(this._repo);

  final OrderRepository _repo;

  Future<void> call(Order order, {required RiderApplication rider}) async {
    final ok = await _repo.acceptOrder(
      order.id,
      riderId: rider.uid,
      rider: RiderInfo(name: rider.name, phone: rider.phone, vehicle: rider.vehicleLabel),
    );
    if (!ok) throw const AppException();
  }
}
