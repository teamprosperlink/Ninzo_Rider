import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/repositories/location_repository.dart';

class GeolocatorLocationRepository implements LocationRepository {
  static const _settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20);

  Future<void> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const AppException();
    }
  }

  @override
  Future<LatLng> currentPosition() async {
    await _ensurePermission();
    final p = await Geolocator.getCurrentPosition(locationSettings: _settings);
    return LatLng(p.latitude, p.longitude);
  }

  @override
  Stream<LatLng> positionStream() async* {
    await _ensurePermission();
    // The stream only speaks after the phone moves; a rider standing still needs where they are now.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) yield LatLng(last.latitude, last.longitude);
    yield* Geolocator.getPositionStream(locationSettings: _settings).map((p) => LatLng(p.latitude, p.longitude));
  }
}
