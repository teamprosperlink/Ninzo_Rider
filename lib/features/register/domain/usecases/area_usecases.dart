import 'package:latlong2/latlong.dart';

import '../../../location/domain/repositories/location_repository.dart';
import '../entities/register_failure.dart';
import '../entities/rider_area.dart';
import '../repositories/area_repository.dart';

/// Register 14–16: popular areas while the search is empty, otherwise every
/// area whose name contains the text (names starting with it first).
class SearchAreas {
  const SearchAreas(this._areas);

  final AreaRepository _areas;

  Future<List<RiderArea>> call(String query) async {
    final all = await _areas.all();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all.where((a) => a.popular).toList();
    final matches = all.where((a) => a.name.toLowerCase().contains(q)).toList();
    int rank(RiderArea a) =>
        (a.name.toLowerCase().startsWith(q) ? 0 : 2) + (a.popular ? 0 : 1);
    matches.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.name.compareTo(b.name);
    });
    return matches;
  }
}

/// "Use my current location": the nearest area within [maxKm] of the phone.
class FindAreaNearMe {
  const FindAreaNearMe(this._areas, this._location, {this.maxKm = 25});

  final AreaRepository _areas;
  final LocationRepository _location;
  final double maxKm;

  Future<RiderArea> call() async {
    final LatLng here;
    try {
      here = await _location.currentPosition();
    } on Object {
      throw const RegisterFailure(RegisterFailureKind.locationUnavailable);
    }
    const distance = Distance();
    RiderArea? best;
    var bestKm = double.infinity;
    for (final area in await _areas.all()) {
      if (area.latitude == null || area.longitude == null) continue;
      final km =
          distance.as(
            LengthUnit.Meter,
            here,
            LatLng(area.latitude!, area.longitude!),
          ) /
          1000;
      if (km < bestKm) {
        bestKm = km;
        best = area;
      }
    }
    if (best == null || bestKm > maxKm) {
      throw const RegisterFailure(RegisterFailureKind.noAreaNearby);
    }
    return best;
  }
}
