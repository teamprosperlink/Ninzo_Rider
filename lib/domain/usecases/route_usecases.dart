import 'package:latlong2/latlong.dart';

import '../repositories/route_repository.dart';

/// The next turn on the way to a place.
class NextRouteStep {
  const NextRouteStep(this._repository);

  final RouteRepository _repository;

  Future<RouteStep> call(LatLng from, LatLng to) => _repository.nextStep(from, to);
}
