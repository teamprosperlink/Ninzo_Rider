import '../../core/constants/app_strings.dart';
/// What the rider can report (Problem 01).
enum ProblemKind {
  breakdown(AppStrings.breakdown, AppStrings.scooterWonTRun),
  accident(AppStrings.accident, AppStrings.tellUsYouReSafe),
  gateClosed(AppStrings.gateClosed, AppStrings.canTGetIn),
  customerAbsent(AppStrings.customerAbsent, AppStrings.notAtTheGate),
  unsafeRoute(AppStrings.unsafeRoute, AppStrings.roadFeelsUnsafe);

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
