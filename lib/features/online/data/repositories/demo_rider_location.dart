import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../../core/config/demo_data.dart';
import '../../../location/domain/repositories/location_repository.dart';
import '../../../shift/domain/repositories/route_repository.dart';
import '../../domain/usecases/spot_usecases.dart';

/// The demo rider around the sample spot (emulators sit far away): the real
/// distance rules run on this simulated position.
class DemoRiderLocation implements LocationRepository {
  LatLng _spot = const LatLng(DemoData.spotLat, DemoData.spotLng);

  double _meters = DemoData.riderStartMeters;

  /// Set while the rider is out on an order, away from the spot.
  LatLng? _onOrder;
  final _changes = StreamController<LatLng>.broadcast();
  final _timers = <Timer>[];

  LatLng get _position => _onOrder ?? const Distance().offset(_spot, _meters, DemoData.riderBearing);

  /// The rider's spot changed (Shift 37): they're this far from the new one.
  void changeSpot(LatLng spot, double meters) {
    _cancel();
    _spot = spot;
    _go(meters);
  }

  /// Puts the rider at [point], out on an order.
  void moveToPoint(LatLng point) {
    _cancel();
    _onOrder = point;
    _changes.add(point);
  }

  /// Puts the rider this far from the spot, stopping any ride.
  void moveTo(double meters) {
    _cancel();
    _go(meters);
  }

  void _go(double meters) {
    _onOrder = null;
    _meters = meters;
    _changes.add(_position);
  }

  /// Rides to the spot: to "Almost there" (Shift 22), then the spot (23).
  void ride() {
    _cancel();
    final far = _meters > SpotRules.almostThereMeters;
    if (far) _timers.add(Timer(DemoData.rideLeg, () => _go(DemoData.riderAlmostMeters)));
    if (_meters > SpotRules.atSpotMeters) {
      _timers.add(Timer(far ? DemoData.rideLeg * 2 : DemoData.rideLeg, () => _go(DemoData.riderAtSpotMeters)));
    }
  }

  void _cancel() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  Future<LatLng> currentPosition() async => _position;

  @override
  Stream<LatLng> positionStream() async* {
    yield _position;
    yield* _changes.stream;
  }

  void dispose() {
    _cancel();
    _changes.close();
  }
}

/// The design's sample turns (Shift 21, 22) with the real distance left.
class DemoSpotRouteRepository implements RouteRepository {
  const DemoSpotRouteRepository();

  @override
  Future<RouteStep> nextStep(LatLng from, LatLng to) async {
    final meters = SpotRules.metersBetween(from, to);
    final far = meters > SpotRules.almostThereMeters;
    return RouteStep(
      instruction: far ? 'In 120 m, turn right' : 'In 60 m, turn left',
      street: far ? 'Onto 2nd Cross' : 'Onto 3rd Main',
      maneuver: far ? 'Turn right' : 'Turn left',
      totalKm: meters / 1000,
    );
  }
}
