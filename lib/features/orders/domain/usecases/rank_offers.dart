import 'package:latlong2/latlong.dart';

import '../entities/order.dart';
import '../entities/order_offer.dart';

/// Picks which open orders to offer the rider: not skipped, and with the
/// restaurant within [radiusKm] so the food stays hot. Nearest first once
/// the rider's position is known.
class RankOffers {
  const RankOffers();

  static const radiusKm = 2.0;

  List<OrderOffer> call(List<Order> orders, {LatLng? from, Set<String> skipped = const {}}) {
    final offers = [
      for (final o in orders)
        if (!skipped.contains(o.id))
          OrderOffer(o, kmToRestaurant: from == null ? null : Order.kmBetween(from, o.restaurant.point)),
    ].where((o) => (o.kmToRestaurant ?? 0) <= radiusKm).toList();
    if (from != null) offers.sort((a, b) => a.kmToRestaurant!.compareTo(b.kmToRestaurant!));
    return offers;
  }
}
