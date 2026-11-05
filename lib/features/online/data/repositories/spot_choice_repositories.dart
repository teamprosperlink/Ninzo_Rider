import 'package:latlong2/latlong.dart';

import '../../../../core/config/demo_data.dart';
import '../../domain/entities/spot_option.dart';
import '../../domain/repositories/spot_choice_repository.dart';

/// Outside demo mode nothing leads to Choose a spot, because the backend
/// assigns spots: there's no backend to read choices from.
class NoSpotChoices implements SpotChoiceRepository {
  const NoSpotChoices();

  @override
  Future<List<SpotOption>> nearbySpots(String uid) async => const [];

  @override
  Future<bool> claimSpot(String uid, String shiftId, SpotOption spot) async => false;
}

/// In-memory spots for demo mode, as Shift 14 draws them. The demo pills play
/// the backend through [fill], [noneFree] and [reset].
class DemoSpotChoiceRepository implements SpotChoiceRepository {
  /// Every spot has a rider (Shift 18).
  bool noneFree = false;

  final _filled = <String>{};

  void fill(String name) => _filled.add(name);

  /// Back to the sample spots.
  void reset() {
    noneFree = false;
    _filled.clear();
  }

  @override
  Future<List<SpotOption>> nearbySpots(String uid) async {
    await Future<void>.delayed(DemoData.findingSpots);
    final spots = <SpotOption>[];
    for (final (name, km, taken, capacity, lat, lng) in DemoData.choiceSpots) {
      final spot = SpotOption(name: name, km: km, taken: taken, capacity: capacity, point: LatLng(lat, lng));
      spots.add(noneFree || _filled.contains(name) ? spot.filled : spot);
    }
    return spots;
  }

  @override
  Future<bool> claimSpot(String uid, String shiftId, SpotOption spot) async {
    await Future<void>.delayed(DemoData.confirmingSpot);
    return !noneFree && !_filled.contains(spot.name);
  }
}
