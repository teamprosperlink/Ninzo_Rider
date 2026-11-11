import 'package:latlong2/latlong.dart';

import '../repositories/location_repository.dart';
import '../entities/register_failure.dart';
import '../entities/rider_area.dart';
import '../repositories/area_repository.dart';
import '../repositories/place_repository.dart';

/// Register 14–16: popular areas while the search is empty, otherwise real
/// places matching the text.
class SearchAreas {
  const SearchAreas(this._areas, this._places);

  final AreaRepository _areas;
  final PlaceRepository _places;

  Future<List<RiderArea>> call(String query) async {
    final q = query.trim();
    if (q.isEmpty) return (await _areas.all()).where((a) => a.popular).toList();
    return _places.search(q);
  }
}

/// The picked place, with its coordinates.
class ResolveArea {
  const ResolveArea(this._places);

  final PlaceRepository _places;

  Future<RiderArea> call(RiderArea area) => _places.details(area);
}

/// "Use my current location": the area the phone is in.
class FindAreaNearMe {
  const FindAreaNearMe(this._places, this._location);

  final PlaceRepository _places;
  final LocationRepository _location;

  Future<RiderArea> call() async {
    final LatLng here;
    try {
      here = await _location.currentPosition();
    } on Object {
      throw const RegisterFailure(RegisterFailureKind.locationUnavailable);
    }
    final area = await _places.near(here);
    if (area == null) throw const RegisterFailure(RegisterFailureKind.noAreaNearby);
    return area;
  }
}
