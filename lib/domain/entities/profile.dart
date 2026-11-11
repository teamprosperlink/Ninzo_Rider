/// What the backend keeps about the rider beyond the registration (Profile 04,
/// 07).
class ProfileFacts {
  const ProfileFacts({this.riderSince, this.spotAssignedAt});

  /// "Rider since".
  final DateTime? riderSince;

  /// "Assigned".
  final DateTime? spotAssignedAt;
}

/// One line of the Notifications list (Profile 05).
class RiderNotification {
  const RiderNotification({required this.id, required this.title, required this.body, required this.at});

  final String id;
  final String title;
  final String body;
  final DateTime at;
}

/// One past or running shift (Profile 06).
class ShiftRecord {
  const ShiftRecord({
    required this.date,
    required this.orders,
    required this.earned,
    required this.onlineAt,
    required this.plannedEnd,
    this.endedAt,
  });

  /// The day of the shift.
  final DateTime date;
  final int orders;
  final double earned;

  /// When the rider first went online; null when they never did.
  final DateTime? onlineAt;
  final DateTime plannedEnd;
  final DateTime? endedAt;
}

/// A document on Profile 08.
class ProfileDocument {
  const ProfileDocument({required this.label, required this.verified});

  final String label;
  final bool verified;
}
