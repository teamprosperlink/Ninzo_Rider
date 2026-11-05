import '../entities/shift_end.dart';

/// What the phone says about the things riding depends on (Shift 41, 42).
abstract interface class DeviceHealthRepository {
  /// Location services on and permission granted.
  Future<bool> locationOn();

  /// The phone sets its date and time automatically.
  Future<bool> phoneTimeAutomatic();

  Future<void> openLocationSettings();

  Future<void> openDateSettings();
}

/// Which phone holds the rider's shift (Shift 54), and when it ended.
abstract interface class ShiftSessionRepository {
  /// Whether another phone has this shift open.
  Future<bool> openElsewhere(String uid, String shiftId);

  /// This phone takes the shift.
  Future<void> claim(String uid, String shiftId);

  /// Stamps the moment the shift ended.
  Future<void> markEnded(String uid, String shiftId);
}

/// What waits on the phone for signal (Shift 40, Sync 01).
abstract interface class SyncStatusRepository {
  Future<SyncSnapshot> load(String uid);

  /// Sends what it can now.
  Future<void> retry(String uid);
}
