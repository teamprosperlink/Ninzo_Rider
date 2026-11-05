import '../entities/rider_area.dart';

/// Areas riders can register for (Register 14–16).
abstract interface class AreaRepository {
  /// Every area, popular ones first.
  Future<List<RiderArea>> all();
}
