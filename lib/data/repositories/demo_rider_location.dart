import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../core/constants/demo_data.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/usecases/spot_usecases.dart';
import '../../core/constants/app_strings.dart';

/// The demo rider around the sample spot (emulators sit far away): the real
/// distance rules run on this simulated position.
class DemoRiderLocation implements LocationRepository {
  /// Given the phone's GPS, the rider is wherever the phone is, and the
  /// scripted moves below do nothing.
  DemoRiderLocation([this._device]);

  final LocationRepository? _device;

  LatLng _spot = const LatLng(DemoData.spotLat, DemoData.spotLng);

  double _meters = DemoData.riderStartMeters;

  /// Set while the rider is out on an order, away from the spot.
  LatLng? _onOrder;
  final _changes = StreamController<LatLng>.broadcast();
  final _timers = <Timer>[];

  LatLng get _position => _onOrder ?? const Distance().offset(_spot, _meters, DemoData.riderBearing);

  /// The rider's spot changed (Shift 37): they're this far from the new one.
  void changeSpot(LatLng spot, double meters) {
    if (_device != null) return;
    _cancel();
    _spot = spot;
    _go(meters);
  }

  /// Puts the rider at [point], out on an order.
  void moveToPoint(LatLng point) {
    if (_device != null) return;
    _cancel();
    _onOrder = point;
    _changes.add(point);
  }

  /// Puts the rider this far from the spot, stopping any ride.
  void moveTo(double meters) {
    if (_device != null) return;
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
    if (_device != null) return;
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
  Future<LatLng> currentPosition() async => await _device?.currentPosition() ?? _position;

  @override
  Stream<LatLng> positionStream() async* {
    final device = _device;
    if (device != null) {
      yield* device.positionStream();
      return;
    }
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
      instruction: far ? AppStrings.in120MTurnRight : AppStrings.in60MTurnLeft,
      street: far ? AppStrings.onto2ndCross : AppStrings.onto3rdMain,
      maneuver: far ? AppStrings.turnRight : AppStrings.turnLeft,
      totalKm: meters / 1000,
    );
  }
}
