import 'package:latlong2/latlong.dart';

enum SpotProximity {
  /// Shift 21.
  far,

  /// Shift 22 "Almost there".
  almostThere,

  /// Reached: Shift 23.
  atSpot,
}

/// What checking the location after "Yes, I'm at the spot" found.
sealed class SpotCheck {
  const SpotCheck();
}

/// Within reach of the spot, or the phone can't tell: the rider's word
/// stands (Shift 23 "Your phone can't pinpoint your location").
class SpotConfirmed extends SpotCheck {
  const SpotConfirmed();
}

/// Clearly somewhere else: Shift 22.
class SpotTooFar extends SpotCheck {
  const SpotTooFar(this.position);

  final LatLng position;
}

enum GoOnlineAtSpotResult { online, noSignal }
