import '../../core/constants/app_strings.dart';
import 'rider_settings.dart';
/// What the rider can report (Problem 01). The kinds are the rider API's
/// (`problem_types`); [code] is reportProblem's type.
class ProblemKind {
  const ProblemKind(this.code, this.label, this.hint);

  final String code;
  final String label;
  final String hint;

  static const breakdown = ProblemKind('breakdown', AppStrings.breakdown, AppStrings.scooterWonTRun);
  static const accident = ProblemKind('accident', AppStrings.accident, AppStrings.tellUsYouReSafe);
  static const gateClosed = ProblemKind('gate_closed', AppStrings.gateClosed, AppStrings.canTGetIn);
  static const customerAbsent = ProblemKind('customer_absent', AppStrings.customerAbsent, AppStrings.notAtTheGate);
  static const unsafeRoute = ProblemKind('unsafe_route', AppStrings.unsafeRoute, AppStrings.roadFeelsUnsafe);

  static List<ProblemKind> get values => RiderSettings.current.problemKinds;

  @override
  bool operator ==(Object other) => other is ProblemKind && other.code == code;

  @override
  int get hashCode => code.hashCode;
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
