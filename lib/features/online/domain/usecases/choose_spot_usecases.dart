import '../../../shift/domain/entities/shift.dart';
import '../../../shift/domain/repositories/shift_repository.dart';
import '../entities/spot_option.dart';
import '../repositories/spot_choice_repository.dart';

abstract final class SpotChoiceRules {
  /// Nothing free near the rider: Shift 18.
  static bool anyFree(List<SpotOption> spots) => spots.any((s) => !s.isFull);

  /// Shift 17: the spot that filled up, then the free ones. Those already full
  /// aren't listed.
  static List<SpotOption> afterFilled(List<SpotOption> spots, SpotOption filled) => [
    filled,
    ...spots.where((s) => s.name != filled.name && !s.isFull),
  ];
}

/// Shift 13: the spots near the rider, nearest first.
class FindSpots {
  const FindSpots(this._spots);

  final SpotChoiceRepository _spots;

  Future<List<SpotOption>> call(String uid) async {
    final spots = await _spots.nearbySpots(uid);
    return [...spots]..sort((a, b) => a.km.compareTo(b.km));
  }
}

enum ConfirmSpotResult { confirmed, spotFull }

/// Shift 16: takes a place at the spot, which is the rider's from now on.
class ConfirmSpot {
  const ConfirmSpot(this._spots, this._shifts);

  final SpotChoiceRepository _spots;
  final ShiftRepository _shifts;

  Future<ConfirmSpotResult> call(String uid, Shift shift, SpotOption spot) async {
    if (!await _spots.claimSpot(uid, shift.id, spot)) return ConfirmSpotResult.spotFull;
    await _shifts.setSpot(uid, shift.id, Spot(name: spot.name, point: spot.point));
    return ConfirmSpotResult.confirmed;
  }
}
