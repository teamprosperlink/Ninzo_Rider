import '../entities/handover.dart';
import '../entities/problem_report.dart';

/// The phone's own copy of what waits to sync, per rider.
abstract interface class HandoverStore {
  Future<HandoverLocalState> load(String uid);

  Future<void> save(String uid, HandoverLocalState state);
}

/// Where problem reports go.
abstract interface class ProblemReportRepository {
  Future<void> send(ProblemReport report);
}
