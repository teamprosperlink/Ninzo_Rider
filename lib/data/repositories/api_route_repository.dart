import 'package:latlong2/latlong.dart';

import '../../core/constants/app_strings.dart';
import '../../domain/repositories/route_repository.dart';
import '../datasources/remote/rider_api_client.dart';
import '../datasources/remote/rider_api_session.dart';
import 'google_route_repository.dart' show decodePolyline;
import 'route_repositories.dart';

/// The rider API's route to the gate (`GET /orders/{id}/route`): the line
/// the server worked out, for when Google can't be reached. The API has no
/// turns, so it reads "Continue" until the gate. Without the API either, the
/// straight line.
class ApiRouteRepository implements RouteRepository {
  ApiRouteRepository(this._session);

  final RiderApiSession _session;
  static const _distance = Distance();

  @override
  Future<RouteStep> nextStep(LatLng from, LatLng to) async {
    final orderId = _session.activeOrderId;
    if (orderId == null) return const StraightLineRouteRepository().nextStep(from, to);
    try {
      final json = await _session.api.getRoute(orderId);
      final points = decodePolyline(json['polyline'] as String? ?? '');
      if (points.length < 2) return await const StraightLineRouteRepository().nextStep(from, to);
      final path = [from, ...points.skip(_nearest(from, points) + 1)];
      var meters = 0.0;
      for (var i = 1; i < path.length; i++) {
        meters += _distance.as(LengthUnit.Meter, path[i - 1], path[i]);
      }
      return RouteStep(
        instruction: AppStrings.routeContinue,
        maneuver: AppStrings.routeContinue,
        totalKm: meters / 1000,
        path: path,
      );
    } on RiderApiException {
      return const StraightLineRouteRepository().nextStep(from, to);
    }
  }

  static int _nearest(LatLng from, List<LatLng> points) {
    var best = 0;
    var bestMeters = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final meters = _distance.as(LengthUnit.Meter, from, points[i]);
      if (meters < bestMeters) {
        best = i;
        bestMeters = meters;
      }
    }
    return best;
  }
}
