import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/error/app_exception.dart';
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
    yield* Geolocator.getPositionStream(locationSettings: _settings).map((p) => LatLng(p.latitude, p.longitude));
  }
}
