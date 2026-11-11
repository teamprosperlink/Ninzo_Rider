import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/app_exception.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/formatters.dart';
import '../../domain/repositories/route_repository.dart';
import '../datasources/remote/google_api.dart';
import 'route_repositories.dart';

/// Real roads and turns from Google Routes. One route is fetched per trip and
/// followed on the phone; it's fetched again only when the rider leaves it, as
/// each request costs money. Without Google, falls back to [_fallback]
/// (the straight line, or the rider API's route).
class GoogleRouteRepository implements RouteRepository {
  GoogleRouteRepository(this._api, {http.Client? client, RouteRepository? fallback})
    : _client = client ?? http.Client(),
      _fallback = fallback ?? const StraightLineRouteRepository();

  /// Where the route comes from without Google.
  final RouteRepository _fallback;

  static const _offRouteMeters = 100.0;
  static const _sameDestinationMeters = 5.0;
  static const _minFetchGap = Duration(seconds: 20);
  static const _distance = Distance();

  final GoogleApi _api;
  final http.Client _client;
  LatLng? _destination;
  List<_Step> _steps = const [];
  DateTime? _fetchedAt;

  @override
  Future<RouteStep> nextStep(LatLng from, LatLng to) async {
    try {
      final sameTrip = _destination != null && _distance.as(LengthUnit.Meter, _destination!, to) <= _sameDestinationMeters;
      var at = sameTrip ? _nearest(from) : null;
      final waited = _fetchedAt == null || DateTime.now().difference(_fetchedAt!) >= _minFetchGap;
      if (!sameTrip || at == null || (at.meters > _offRouteMeters && waited)) {
        await _fetch(from, to);
        at = _nearest(from);
      }
      if (at == null) throw const AppException();
      return _stepFrom(from, at);
    } on Object {
      return _fallback.nextStep(from, to);
    }
  }

  RouteStep _stepFrom(LatLng from, _Position at) {
    final step = _steps[at.step];
    final left = <LatLng>[from, ...step.points.skip(at.vertex + 1)];
    var toTurn = _length(left);
    final path = [...left];
    for (final later in _steps.skip(at.step + 1)) {
      path.addAll(later.points.skip(1));
    }
    final next = at.step + 1 < _steps.length ? _steps[at.step + 1] : null;
    if (next == null) toTurn = _distance.as(LengthUnit.Meter, from, step.points.last);
    final turn = next?.turn ?? AppStrings.routeArrive;
    return RouteStep(
      instruction: AppStrings.routeInstruction(distance(toTurn / 1000), turn.toLowerCase()),
      street: next?.street,
      maneuver: turn,
      totalKm: _length(path) / 1000,
      path: path,
    );
  }

  double _length(List<LatLng> points) {
    var sum = 0.0;
    for (var i = 1; i < points.length; i++) {
      sum += _distance.as(LengthUnit.Meter, points[i - 1], points[i]);
    }
    return sum;
  }

  /// The closest piece of the route to [point].
  _Position? _nearest(LatLng point) {
    _Position? best;
    for (var s = 0; s < _steps.length; s++) {
      final points = _steps[s].points;
      for (var v = 0; v + 1 < points.length; v++) {
        final meters = _toSegment(point, points[v], points[v + 1]);
        if (best == null || meters < best.meters) best = _Position(s, v, meters);
      }
    }
    return best;
  }

  double _toSegment(LatLng p, LatLng a, LatLng b) {
    final scale = math.cos(p.latitudeInRad);
    final bx = (b.longitude - a.longitude) * scale, by = b.latitude - a.latitude;
    final px = (p.longitude - a.longitude) * scale, py = p.latitude - a.latitude;
    final squared = bx * bx + by * by;
    final t = squared == 0 ? 0.0 : ((px * bx + py * by) / squared).clamp(0.0, 1.0);
    return _distance.as(LengthUnit.Meter, p, LatLng(a.latitude + by * t, a.longitude + (b.longitude - a.longitude) * t));
  }

  Future<void> _fetch(LatLng from, LatLng to) async {
    _fetchedAt = DateTime.now();
    Map<String, dynamic> place(LatLng p) => {
      'location': {
        'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
      },
    };
    final response = await _client.post(
      Uri.parse(ApiEndpoints.routes),
      headers: {
        ...await _api.headers(),
        'Content-Type': 'application/json',
        'X-Goog-FieldMask': 'routes.legs.steps.polyline.encodedPolyline,routes.legs.steps.navigationInstruction',
      },
      body: jsonEncode({
        'origin': place(from),
        'destination': place(to),
        'travelMode': 'TWO_WHEELER',
        'languageCode': 'en',
      }),
    );
    if (response.statusCode != 200) throw const AppException();
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) throw const AppException();
    final legs = (routes.first as Map<String, dynamic>)['legs'] as List<dynamic>;
    final steps = <_Step>[];
    for (final leg in legs) {
      for (final raw in (leg as Map<String, dynamic>)['steps'] as List<dynamic>) {
        final step = raw as Map<String, dynamic>;
        final polyline = (step['polyline'] as Map<String, dynamic>?)?['encodedPolyline'] as String?;
        if (polyline == null) continue;
        final points = decodePolyline(polyline);
        if (points.length < 2) continue;
        final navigation = step['navigationInstruction'] as Map<String, dynamic>?;
        steps.add(
          _Step(
            points,
            _turnName(navigation?['maneuver'] as String?),
            _streetIn(navigation?['instructions'] as String?),
          ),
        );
      }
    }
    if (steps.isEmpty) throw const AppException();
    _steps = steps;
    _destination = to;
  }

  String _turnName(String? maneuver) => switch (maneuver) {
    'TURN_LEFT' => AppStrings.turnLeft,
    'TURN_RIGHT' => AppStrings.turnRight,
    'TURN_SLIGHT_LEFT' => AppStrings.routeSlightLeft,
    'TURN_SLIGHT_RIGHT' => AppStrings.routeSlightRight,
    'TURN_SHARP_LEFT' => AppStrings.routeSharpLeft,
    'TURN_SHARP_RIGHT' => AppStrings.routeSharpRight,
    'UTURN_LEFT' || 'UTURN_RIGHT' => AppStrings.routeUTurn,
    'ROUNDABOUT_LEFT' || 'ROUNDABOUT_RIGHT' => AppStrings.routeRoundabout,
    'RAMP_LEFT' || 'FORK_LEFT' => AppStrings.routeKeepLeft,
    'RAMP_RIGHT' || 'FORK_RIGHT' => AppStrings.routeKeepRight,
    _ => AppStrings.routeContinue,
  };

  /// "Turn left onto Service Rd" gives "Onto Service Rd".
  String? _streetIn(String? instructions) {
    if (instructions == null) return null;
    final line = instructions.split('\n').first;
    final match = RegExp(r'\b(onto|on|toward)\s+(.+)$', caseSensitive: false).firstMatch(line);
    if (match == null) return null;
    final word = match.group(1)!;
    return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()} ${match.group(2)}';
  }
}

class _Step {
  const _Step(this.points, this.turn, this.street);

  final List<LatLng> points;

  /// How this step starts: "Turn left".
  final String turn;
  final String? street;
}

class _Position {
  const _Position(this.step, this.vertex, this.meters);

  final int step;
  final int vertex;
  final double meters;
}

/// Google's encoded polyline format.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0, lat = 0, lng = 0;
  int next() {
    var shift = 0, result = 0, byte = 0;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += next();
    lng += next();
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
