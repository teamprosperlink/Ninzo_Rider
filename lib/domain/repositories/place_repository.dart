import 'package:latlong2/latlong.dart';

import '../entities/rider_area.dart';

/// Real places, from a map provider (Register 14–16).
abstract interface class PlaceRepository {
  /// Places matching what the rider typed; their coordinates come with [details].
  Future<List<RiderArea>> search(String query);

  /// [area] with its coordinates.
  Future<RiderArea> details(RiderArea area);

  /// The area at [point], or null when there's none.
  Future<RiderArea?> near(LatLng point);
}
