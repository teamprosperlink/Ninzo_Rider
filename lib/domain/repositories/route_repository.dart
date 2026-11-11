import 'package:latlong2/latlong.dart';

import '../entities/route_step.dart';

export '../entities/route_step.dart';

/// Turn-by-turn directions.
abstract interface class RouteRepository {
  Future<RouteStep> nextStep(LatLng from, LatLng to);
}
