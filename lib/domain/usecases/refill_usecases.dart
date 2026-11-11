import '../../core/errors/app_exception.dart';
import '../entities/online_status.dart';
import '../repositories/online_repository.dart';
import 'online_usecases.dart';
import '../entities/shift.dart';
import '../repositories/shift_repository.dart';
import '../entities/stock.dart';
import '../repositories/stock_repository.dart';
import '../entities/restock.dart';
import '../entities/refill_prompt.dart';

export '../entities/refill_prompt.dart';

/// Refill 01 shows at this many portions left.
// TODO(design): the flow map has no arrow into Refill 01; its sample says 1.
const refillPromptAt = 1;

/// An order to finish comes first; "Stay online" keeps the rider on the map
/// until they run out.
RefillPrompt refillPromptOf(Shift shift, OnlineStatus status, {bool stayedOnline = false}) {
  if (shift.phase != ShiftPhase.online || status.queue.isNotEmpty || status.activeOrderId != null) {
    return RefillPrompt.none;
  }
  final left = scooterStockOf(shift, status).portionsLeft;
  if (left == 0) return RefillPrompt.outOfStock;
  if (left <= refillPromptAt && !stayedOnline) return RefillPrompt.lowStock;
  return RefillPrompt.none;
}

/// "Request hub to prepare" (Shift 29), "Go refill" (Refill 01), "Navigate to
/// hub" (Refill 02), "Head to Hub 2" (Restock 03) → Refill 03. Each refill is
/// its own load, with its own scans.
class StartRefill {
  const StartRefill(this._shifts, this._stock);

  final ShiftRepository _shifts;
  final StockRepository _stock;

  Future<void> call(String uid, Shift shift, {String? hubName, List<RestockLine> lines = const []}) async {
    if (shift.phase != ShiftPhase.online) throw const AppException();
    final round = shift.refillRound + 1;
    final asked = lines.where((l) => l.quantity > 0).toList();
    if (asked.isNotEmpty) {
      await _stock.prepareLoad(uid, Shift.loadIdFor(shift.id, round), [
        for (final line in asked) StockItem(id: line.itemId, name: line.name, quantity: line.quantity),
      ]);
    }
    await _shifts.setRefill(
      uid,
      shift.id,
      refill: RefillLoad(hubName: hubName ?? shift.hub.name),
      round: round,
      phase: ShiftPhase.atHub,
    );
  }
}

/// Back from Refill 03: on to the main map, no refill.
class CancelRefill {
  const CancelRefill(this._shifts);

  final ShiftRepository _shifts;

  Future<void> call(String uid, Shift shift) =>
      _shifts.setRefill(uid, shift.id, refill: null, round: shift.refillRound, phase: ShiftPhase.online);
}

/// "Go online" (Refill 04 → Shift 26): what was scanned joins what's on the
/// scooter.
class FinishRefill {
  const FinishRefill(this._shifts, this._online);

  final ShiftRepository _shifts;
  final OnlineRepository _online;

  Future<void> call(String uid, Shift shift, int portions) async {
    await _online.addStock(uid, shift.id, portions);
    await _shifts.setRefill(uid, shift.id, refill: null, round: shift.refillRound, phase: ShiftPhase.online);
  }
}

/// The rider's answers to a restock (Restock 01–05).
class AnswerRestock {
  const AnswerRestock(this._online, this._startRefill);

  final OnlineRepository _online;
  final StartRefill _startRefill;

  /// "Confirm restock" → Restock 03.
  Future<void> confirm(String uid, String shiftId, RestockRequest request, List<RestockLine> lines) async {
    if (RestockRules.total(lines) < 1) throw const AppException();
    if (RestockRules.total(lines) > RestockRules.scooterHolds) {
      throw const AppException();
    }
    await _online.setRestock(
      uid,
      shiftId,
      request.copyWith(stage: RestockStage.inProgress, lines: lines, expiresAt: () => null),
    );
  }

  /// "Not now", "Cancel restock", "Back to waiting" → Shift 26.
  Future<void> dismiss(String uid, String shiftId) => _online.setRestock(uid, shiftId, null);

  /// "Take 2 from Hub 2" → Restock 03, with what the hub can give.
  Future<void> takeWhatHubHas(String uid, String shiftId, RestockRequest request) async {
    final shortage = request.shortage;
    if (shortage == null) throw const AppException();
    await _online.setRestock(
      uid,
      shiftId,
      request.copyWith(
        stage: RestockStage.inProgress,
        shortage: () => null,
        lines: [
          for (final line in request.lines)
            line.name == shortage.itemName ? line.withQuantity(shortage.canGive) : line,
        ],
      ),
    );
  }

  /// "Try Hub 4" → Restock 03, at that hub.
  Future<void> tryOtherHub(String uid, String shiftId, RestockRequest request) async {
    final shortage = request.shortage;
    if (shortage == null) throw const AppException();
    await _online.setRestock(
      uid,
      shiftId,
      request.copyWith(stage: RestockStage.inProgress, hubName: shortage.otherHubName, shortage: () => null),
    );
  }

  /// "Head to Hub 2" → Refill 03.
  Future<void> headToHub(String uid, Shift shift, RestockRequest request) async {
    await _startRefill(uid, shift, hubName: request.hubName, lines: request.lines);
    await _online.setRestock(uid, shift.id, null);
  }
}
