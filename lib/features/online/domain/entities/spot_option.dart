import 'package:latlong2/latlong.dart';

/// What a card on Shift 14–17 says on its right. A spot with room and more
/// than one rider has no frame, so it says nothing.
enum SpotTag { bestForOrders, recommended, full }

/// A spot the rider can pick to wait at (Shift 14–17).
class SpotOption {
  const SpotOption({
    required this.name,
    required this.km,
    required this.taken,
    required this.capacity,
    required this.point,
  });

  /// "Yelahanka Node".
  final String name;

  /// How far from the rider.
  final double km;

  /// Riders there already, out of [capacity].
  final int taken;
  final int capacity;
  final LatLng point;

  bool get isFull => taken >= capacity;

  /// 0 to 1, for the fullness bar.
  double get fullness => capacity <= 0 ? 1 : (taken / capacity).clamp(0.0, 1.0);

  SpotTag? get tag => isFull
      ? SpotTag.full
      : taken == 0
      ? SpotTag.bestForOrders
      : taken == 1
      ? SpotTag.recommended
      : null;

  /// This spot with no room left.
  SpotOption get filled => SpotOption(name: name, km: km, taken: capacity, capacity: capacity, point: point);
}
