import '../entities/profile.dart';

/// The rider's records behind Profile 02–09.
abstract interface class ProfileRepository {
  Stream<ProfileFacts> watchFacts(String uid);

  /// Newest first.
  Stream<List<RiderNotification>> watchNotifications(String uid);

  /// Newest first.
  Stream<List<ShiftRecord>> watchShifts(String uid);

  /// The help centre's questions and answers, in order (Profile 02).
  Stream<List<HelpArticle>> watchHelp(String uid);

  /// "Send feedback" (Profile 09).
  Future<void> sendFeedback(String uid, String message);
}
