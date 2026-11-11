import '../../core/errors/app_exception.dart';
import '../entities/shift.dart';
import '../repositories/shift_repository.dart';

/// "I'm coming" / "Ask hub to prepare" (Notification 05–06, Shift 01, 02,
/// 51) or "Not today" (Notification 05–06). The hub packs only after a yes.
class ReplyToStockRequest {
  const ReplyToStockRequest(this._repository);

  final ShiftRepository _repository;

  Future<void> call(String uid, Shift shift, {required bool coming}) async {
    // Already confirmed: asking again changes nothing.
    if (shift.stockRequest.confirmed) {
      if (coming) return;
      throw const AppException();
    }
    if (!coming && shift.stockRequest == StockRequestStatus.notWorkingToday) return;
    await _repository.replyToStockRequest(
      uid,
      shift.id,
      coming ? StockRequestStatus.requested : StockRequestStatus.notWorkingToday,
    );
  }
}
