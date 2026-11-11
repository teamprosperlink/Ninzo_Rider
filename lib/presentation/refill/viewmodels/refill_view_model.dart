import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../../domain/entities/online_status.dart';
import '../../online/providers/online_providers.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/stock.dart';
import '../../../domain/entities/restock.dart';

/// What's being collected (Refill 03) or was loaded (Refill 04).
final refillItemsProvider = FutureProvider<List<StockItem>>((ref) async {
  final uid = ref.watch(currentUidProvider);
  final loadId = ref.watch(todayShiftProvider.select((s) => s.value?.stockLoadId));
  if (uid == null || loadId == null) return const [];
  final local = await ref.read(loadStockUseCaseProvider)(uid, loadId);
  return local.manifest?.items ?? const [];
});

class RefillState {
  const RefillState({this.editing, this.busy = false});

  /// Restock 02's quantities while editing.
  final List<RestockLine>? editing;
  final bool busy;
}

/// Refill 01–04 and Restock 01–05: runs the rider's answers through the use
/// cases. Where the rider is lives on the shift and the online status.
class RefillViewModel extends Notifier<RefillState> {
  @override
  RefillState build() {
    // Starts afresh for each rider.
    ref.watch(currentUidProvider);
    return const RefillState();
  }

  Shift? get _shift => ref.read(todayShiftProvider).value;
  OnlineStatus get _status => ref.read(onlineStatusProvider).value ?? const OnlineStatus();
  String get _uid => ref.read(currentUidProvider)!;
  ShiftFlowViewModel get _flow => ref.read(shiftFlowViewModelProvider.notifier);

  Future<void> _run(Future<void> Function(Shift shift) command) async {
    final shift = _shift;
    if (shift == null || state.busy) return;
    state = RefillState(editing: state.editing, busy: true);
    try {
      await command(shift);
    } catch (_) {
      // No frame for this: the screen stays as it was.
    } finally {
      if (ref.mounted) state = RefillState(editing: state.editing);
    }
  }

  // ── Refill 01–04 ──

  /// "Request hub to prepare" (Shift 29), "Go refill" (Refill 01), "Navigate
  /// to hub" (Refill 02) → Refill 03.
  Future<void> goRefill() => _run((shift) => ref.read(startRefillUseCaseProvider)(_uid, shift));

  /// Back from Refill 03: Home in the morning, the main map during a refill.
  Future<void> leaveHub() async {
    if (_shift?.refill == null) {
      _flow.home();
    } else {
      await _run((shift) => ref.read(cancelRefillUseCaseProvider)(_uid, shift));
    }
  }

  /// "Go online" (Refill 04) → Shift 26.
  Future<void> finish() => _run((shift) async {
    final items = await ref.read(refillItemsProvider.future);
    await ref.read(finishRefillUseCaseProvider)(_uid, shift, items.fold(0, (sum, item) => sum + item.quantity));
  });

  // ── Restock 01–05 ──

  /// "Confirm restock" (Restock 01, 02) → 03.
  Future<void> confirmRestock() => _run((shift) async {
    final request = _status.restock;
    if (request == null) return;
    await ref
        .read(answerRestockUseCaseProvider)
        .confirm(_uid, shift.id, request, state.editing ?? request.lines);
    state = RefillState(busy: state.busy);
  });

  /// "Edit quantity" (Restock 01) → 02.
  void editQuantity() {
    final request = _status.restock;
    if (request != null) state = RefillState(editing: request.lines);
  }

  /// "Cancel" and back (Restock 02) → 01.
  void cancelEdit() => state = const RefillState();

  void changeQuantity(int index, int by) {
    final lines = state.editing;
    if (lines == null) return;
    if (by > 0 ? !RestockRules.canAdd(lines) : !RestockRules.canRemove(lines, index)) return;
    state = RefillState(
      editing: [
        for (final (i, line) in lines.indexed) i == index ? line.withQuantity(line.quantity + by) : line,
      ],
    );
  }

  /// "Not now", back (Restock 01), "Cancel restock" (03), "Back to waiting"
  /// (04) → Shift 26.
  Future<void> dismissRestock() => _run((shift) async {
    await ref.read(answerRestockUseCaseProvider).dismiss(_uid, shift.id);
    state = RefillState(busy: state.busy);
  });

  /// Back from Restock 03, 05: the map; the restock carries on.
  // TODO(design): the map has nothing leading back to Restock 03.
  void backToMap() => _flow.show(ShiftScreen.online);

  /// "Take 2 from Hub 2" (Restock 05) → 03.
  Future<void> takeWhatHubHas() => _run((shift) async {
    final request = _status.restock;
    if (request != null) await ref.read(answerRestockUseCaseProvider).takeWhatHubHas(_uid, shift.id, request);
  });

  /// "Try Hub 4" (Restock 05) → 03.
  Future<void> tryOtherHub() => _run((shift) async {
    final request = _status.restock;
    if (request != null) await ref.read(answerRestockUseCaseProvider).tryOtherHub(_uid, shift.id, request);
  });

  /// "Head to Hub 2" (Restock 03) → Refill 03.
  Future<void> headToHub() => _run((shift) async {
    final request = _status.restock;
    if (request != null) await ref.read(answerRestockUseCaseProvider).headToHub(_uid, shift, request);
  });
}

final refillViewModelProvider = NotifierProvider<RefillViewModel, RefillState>(RefillViewModel.new);
