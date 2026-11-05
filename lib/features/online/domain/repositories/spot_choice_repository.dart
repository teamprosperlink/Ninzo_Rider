import '../entities/spot_option.dart';

/// The spots a rider can choose from (Shift 13–18).
abstract interface class SpotChoiceRepository {
  /// The spots near the rider.
  Future<List<SpotOption>> nearbySpots(String uid);

  /// Takes a place at [spot]; false when another rider got the last one.
  Future<bool> claimSpot(String uid, String shiftId, SpotOption spot);
}
