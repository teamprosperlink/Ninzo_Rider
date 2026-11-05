import '../entities/profile.dart';

/// The rider's records behind Profile 04–07.
abstract interface class ProfileRepository {
  Stream<ProfileFacts> watchFacts(String uid);

  /// Newest first.
  Stream<List<RiderNotification>> watchNotifications(String uid);

  /// Newest first.
  Stream<List<ShiftRecord>> watchShifts(String uid);
}
