import 'order.dart';

/// An open order shown to the rider, with how far its restaurant is.
class OrderOffer {
  const OrderOffer(this.order, {this.kmToRestaurant});

  final Order order;

  /// Null until the rider's position is known.
  final double? kmToRestaurant;
}
