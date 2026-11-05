import 'package:latlong2/latlong.dart';

abstract interface class LocationRepository {
  /// The device's position. Throws an AppException when location is off
  /// or permission is denied.
  Future<LatLng> currentPosition();

  /// Device position updates while listened to.
  Stream<LatLng> positionStream();
}
