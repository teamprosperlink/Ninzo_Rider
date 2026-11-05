import 'package:latlong2/latlong.dart';

import '../../domain/repositories/route_repository.dart';

/// Without a routing service: no turn to show, only the straight-line distance.
///
/// TODO(routing): use a directions API (Mapbox / OSRM) for real turns.
class StraightLineRouteRepository implements RouteRepository {
  const StraightLineRouteRepository();

  @override
  Future<RouteStep> nextStep(LatLng from, LatLng to) async {
    final km = const Distance().as(LengthUnit.Meter, from, to) / 1000;
    return RouteStep(instruction: '', street: '', maneuver: '', totalKm: km);
  }
}

/// The design's sample turn (Shift 52).
class DemoRouteRepository implements RouteRepository {
  const DemoRouteRepository(this.totalKm);

  final double totalKm;

  @override
  Future<RouteStep> nextStep(LatLng from, LatLng to) async => RouteStep(
    instruction: 'In 120 m, turn right',
    street: 'Onto 2nd Cross',
    maneuver: 'Turn right',
    totalKm: totalKm,
  );
}
