/// What the rider can report (Problem 01).
enum ProblemKind {
  breakdown('Breakdown', 'Scooter won’t run'),
  accident('Accident', 'Tell us you’re safe'),
  gateClosed('Gate closed', 'Can’t get in'),
  customerAbsent('Customer absent', 'Not at the gate'),
  unsafeRoute('Unsafe route', 'Road feels unsafe');

  const ProblemKind(this.label, this.hint);

  final String label;
  final String hint;
}

/// `problemReports/{id}`; the backend picks it up and answers on the order.
class ProblemReport {
  const ProblemReport({required this.riderId, this.orderId, required this.kind, required this.at});

  final String riderId;
  /// The order under way; null when reported from the Help centre without one.
  final String? orderId;
  final ProblemKind kind;
  final DateTime at;
}
