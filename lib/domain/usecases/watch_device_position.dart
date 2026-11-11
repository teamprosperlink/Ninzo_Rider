import 'package:latlong2/latlong.dart';

import '../repositories/location_repository.dart';

/// Device position updates while listened to. Fails when location is off
/// or permission is denied.
class WatchDevicePosition {
  const WatchDevicePosition(this._repo);

  final LocationRepository _repo;

  Stream<LatLng> call() => _repo.positionStream();
}
