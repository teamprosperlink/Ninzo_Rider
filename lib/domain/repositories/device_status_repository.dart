/// Phone state the pre-shift checklist looks at.
abstract interface class DeviceStatusRepository {
  /// Battery level, 0–100.
  Future<int> phoneBattery();

  /// Location services on and permission granted.
  Future<bool> locationOn();

  /// Opens the system location settings.
  Future<void> openLocationSettings();
}
