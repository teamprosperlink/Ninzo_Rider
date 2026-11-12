import 'package:latlong2/latlong.dart';

import '../repositories/location_repository.dart';
import '../entities/shift.dart';
import '../repositories/shift_repository.dart';
import '../repositories/stock_repository.dart';
import '../entities/online_status.dart';
import '../repositories/online_repository.dart';
import '../entities/spot_check.dart';
import '../entities/rider_settings.dart';

export '../entities/spot_check.dart';

/// How far the rider is from their spot, and what that means.
abstract final class SpotRules {
  /// Within this the rider has reached the spot and can confirm.
  static double get atSpotMeters => RiderSettings.current.arriveMeters;

  /// Within this the rider is "Almost there" (Shift 22 shows 240 m).
  static double get almostThereMeters => RiderSettings.current.almostThereMeters;

  /// An online rider beyond this is away from the spot (Shift 30 shows
  /// 180 m). Wider than [atSpotMeters] so GPS drift doesn't flicker the alert.
  static double get awayFromSpotMeters => RiderSettings.current.awayFromSpotMeters;

  /// Riding speed for the estimate on Shift 19 (1.2 km: 5 min).
  static double get rideSpeedKmh => RiderSettings.current.rideSpeedKmh;

  static double metersBetween(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b);

  static SpotProximity proximity(double meters) => meters <= atSpotMeters
      ? SpotProximity.atSpot
      : meters <= almostThereMeters
      ? SpotProximity.almostThere
      : SpotProximity.far;

  static bool isAway(double meters) => meters > awayFromSpotMeters;

  /// Whole minutes, at least 1.
  static int rideMinutes(double meters) {
    final minutes = (meters / 1000 / rideSpeedKmh * 60).round();
    return minutes < 1 ? 1 : minutes;
  }
}

/// Shift 24 "Checking your location…".
class CheckAtSpot {
  const CheckAtSpot(this._location);

  final LocationRepository _location;

  Future<SpotCheck> call(Spot spot) async {
    final LatLng position;
    try {
      position = await _location.currentPosition();
    } catch (_) {
      return const SpotConfirmed();
    }
    return SpotRules.metersBetween(position, spot.point) <= SpotRules.atSpotMeters
        ? const SpotConfirmed()
        : SpotTooFar(position);
  }
}

/// Shift 24 → 25: the rider is online at the spot, so orders can be assigned.
/// Going online needs signal. The first time starts the Online clock.
class GoOnlineAtSpot {
  const GoOnlineAtSpot(this._online, this._shifts, this._signal);

  final OnlineRepository _online;
  final ShiftRepository _shifts;
  final SignalRepository _signal;

  Future<GoOnlineAtSpotResult> call(String uid, Shift shift, OnlineStatus status) async {
    if (!await _signal.isOnline()) return GoOnlineAtSpotResult.noSignal;
    if (status.onlineAt == null) await _online.markOnline(uid, shift.id);
    // At the new spot: the nudge is done with (Shift 38 → 23 → 25).
    if (status.nudge != null) await _online.setNudge(uid, shift.id, null);
    await _shifts.setPhase(uid, shift.id, ShiftPhase.online);
    return GoOnlineAtSpotResult.online;
  }
}

/// "Navigate to spot" on Shift 30 → 21: no orders until they're back and
/// confirmed. The Online clock keeps running.
class ReturnToSpot {
  const ReturnToSpot(this._shifts);

  final ShiftRepository _shifts;

  Future<void> call(String uid, Shift shift) => _shifts.setPhase(uid, shift.id, ShiftPhase.headingToSpot);
}
