/// What stops the rider, on a screen of its own (Shift 41, 42, 54, 55).
enum ShiftIssue {
  /// Shift 41.
  locationOff,

  /// Shift 42.
  phoneTimeWrong,

  /// Shift 54.
  shiftAlreadyOpen,

  /// Shift 55.
  noInternet,
}

/// What came of opening the shift on this phone (Shift 05).
enum OpenShiftResult {
  opened,

  /// Shift 55.
  noInternet,

  /// Shift 54.
  alreadyOpen,
}

/// What came of "End shift" (Shift 48).
enum EndShiftResult {
  /// Shift 49 → 50.
  ended,

  /// Shift 47.
  orderInProgress,
}

/// Something saved on the phone, waiting for signal (Sync 01).
class SyncEvent {
  const SyncEvent({required this.label, required this.at});

  /// "Handover · #A2931".
  final String label;
  final DateTime at;
}

/// What waits to sync, in the order it will send.
class SyncSnapshot {
  const SyncSnapshot({this.events = const [], this.lastSync, this.deliveries = 0});

  final List<SyncEvent> events;
  final DateTime? lastSync;

  /// Deliveries among them ("1 delivery waiting to sync", Shift 40).
  final int deliveries;
}
