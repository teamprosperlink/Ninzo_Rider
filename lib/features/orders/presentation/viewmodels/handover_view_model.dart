import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/clock_provider.dart';
import '../../../auth/presentation/providers/auth_state_providers.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../../stock/di/stock_di.dart';
import '../../di/orders_di.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/entities/handover.dart';
import '../../domain/entities/order.dart' show OrderItem;
import '../../domain/usecases/handover_usecases.dart';
import 'order_flow_view_model.dart';

/// What the rider is looking at during a handover. Figma's frames are states
/// of fewer screens:
///
/// * [pack]: Handover 01
/// * [quantity]: Handover 08, 09
/// * [code]: Handover 02–05
/// * [waiting]: Handover 07
/// * [details]: Handover 13
/// * [cash]: Handover 12
/// * [saved]: Handover 10
///
/// Handover 06 and 11 follow from the order being delivered.
enum HandoverStep { pack, quantity, code, waiting, details, cash, saved }

class HandoverState {
  const HandoverState({
    this.step = HandoverStep.pack,
    this.from = HandoverStep.pack,
    this.ticked = const {},
    this.quantities,
    this.code = '',
    this.wrongCode = false,
    this.offerNotAtGate = false,
    this.busy = false,
    this.waitingSince,
    this.local = const HandoverLocalState(),
  });

  final HandoverStep step;

  /// Where the code or cash step goes back to.
  final HandoverStep from;

  /// Handover 01's ticks: the items by index, then the bag.
  final Set<int> ticked;

  /// What the customer gets, by item; null is everything ordered.
  final List<int>? quantities;
  final String code;

  /// Handover 04.
  final bool wrongCode;

  /// "Customer not at the gate?" under the empty code boxes.
  final bool offerNotAtGate;

  /// Handover 05 and the like.
  final bool busy;

  /// Handover 07's clock runs from here.
  final DateTime? waitingSince;

  /// What Handover 10 shows.
  final HandoverLocalState local;

  List<int> quantitiesOf(DeliveryOrder order) => quantities ?? orderedQuantities(order);

  HandoverState copyWith({
    HandoverStep? step,
    HandoverStep? from,
    Set<int>? ticked,
    List<int>? Function()? quantities,
    String? code,
    bool? wrongCode,
    bool? offerNotAtGate,
    bool? busy,
    DateTime? waitingSince,
    HandoverLocalState? local,
  }) => HandoverState(
    step: step ?? this.step,
    from: from ?? this.from,
    ticked: ticked ?? this.ticked,
    quantities: quantities == null ? this.quantities : quantities(),
    code: code ?? this.code,
    wrongCode: wrongCode ?? this.wrongCode,
    offerNotAtGate: offerNotAtGate ?? this.offerNotAtGate,
    busy: busy ?? this.busy,
    waitingSince: waitingSince ?? this.waitingSince,
    local: local ?? this.local,
  );
}

/// One order's handover, from "Hand over order" (Arrival 03) until it's
/// delivered or saved on the phone. Starts afresh for each order.
class HandoverViewModel extends Notifier<HandoverState> {
  StreamSubscription<bool>? _signal;
  Timer? _notAtGate;
  bool _leftGate = false;

  @override
  HandoverState build() {
    _leftGate = false;
    final id = ref.watch(onlineStatusProvider.select((s) => s.value?.activeOrderId));
    ref.onDispose(() {
      _signal?.cancel();
      _notAtGate?.cancel();
    });
    if (id != null) {
      _signal = ref.read(watchSignalUseCaseProvider)().listen((online) {
        if (online) _backOnline();
      });
    }
    return const HandoverState();
  }

  DeliveryOrder? get _order => ref.read(activeOrderProvider).value;

  String get _uid => ref.read(currentUidProvider)!;

  Future<void> _run(Future<void> Function(DeliveryOrder order) command) async {
    final order = _order;
    if (order == null || state.busy) return;
    state = state.copyWith(busy: true);
    try {
      await command(order);
      if (ref.mounted) state = state.copyWith(busy: false);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  /// Arrival 03 "Hand over order": a handover saved before the app restarted
  /// picks up where it was.
  Future<void> open() async {
    final order = _order;
    if (order == null) return;
    final local = await ref.read(loadHandoverLocalUseCaseProvider)(_uid);
    if (ref.mounted && local.savedFor(order.id) != null) {
      state = state.copyWith(step: HandoverStep.saved, local: local);
    }
  }

  /// One step back; false when there's none, so the screen leaves the handover.
  bool back() {
    final previous = switch (state.step) {
      HandoverStep.pack || HandoverStep.saved => null,
      HandoverStep.quantity => HandoverStep.pack,
      HandoverStep.code || HandoverStep.cash => state.from,
      HandoverStep.waiting || HandoverStep.details => HandoverStep.code,
    };
    if (previous == null) return false;
    if (previous == HandoverStep.code) _armNotAtGate();
    state = state.copyWith(step: previous);
    return true;
  }

  // ── Handover 01 ──

  void toggle(int check) {
    final ticked = {...state.ticked};
    if (!ticked.remove(check)) ticked.add(check);
    state = state.copyWith(ticked: ticked);
  }

  /// "Packed – go" → the code, or Collect cash.
  void packed() {
    final order = _order;
    if (order != null && isPacked(order, state.ticked)) _toPayment(order, from: HandoverStep.pack);
  }

  /// The flow map's "Check quantity" → Handover 08.
  void checkQuantity() => state = state.copyWith(step: HandoverStep.quantity);

  void _toPayment(DeliveryOrder order, {required HandoverStep from}) {
    if (takesCode(order)) {
      _armNotAtGate();
      state = state.copyWith(step: HandoverStep.code, from: from);
    } else {
      state = state.copyWith(step: HandoverStep.cash, from: from);
    }
  }

  // ── Handover 08, 09 ──

  void changeQuantity(int item, int by) {
    final order = _order;
    if (order == null) return;
    final quantities = [...state.quantitiesOf(order)];
    final quantity = quantities[item] + by;
    if (quantity < 0 || quantity > order.items[item].quantity) return;
    quantities[item] = quantity;
    state = state.copyWith(quantities: () => quantities);
  }

  void resetQuantities() => state = state.copyWith(quantities: () => null);

  /// "Continue to code" → the code or Collect cash; Handover 10 without signal.
  Future<void> continueFromQuantity() => _run((order) async {
    final saved = await ref.read(saveQuantitiesUseCaseProvider)(_uid, order, state.quantitiesOf(order));
    if (!ref.mounted) return;
    if (saved) {
      await _toSaved();
    } else {
      _toPayment(order, from: HandoverStep.quantity);
    }
  });

  // ── Handover 02–05 ──

  /// The flow map's "Not at gate" has no button on Handover 02: the link shows
  /// when nothing's been typed for a while.
  void _armNotAtGate() {
    _notAtGate?.cancel();
    state = state.copyWith(offerNotAtGate: false);
    _notAtGate = Timer(HandoverRules.notAtGateAfter, () {
      if (ref.mounted && state.step == HandoverStep.code && state.code.isEmpty) {
        state = state.copyWith(offerNotAtGate: true);
      }
    });
  }

  void digit(String digit) {
    if (state.busy) return;
    _notAtGate?.cancel();
    // Typing over a wrong code starts it again.
    final code = state.wrongCode ? digit : state.code + digit;
    if (code.length > HandoverRules.codeLength) return;
    state = state.copyWith(code: code, wrongCode: false, offerNotAtGate: false);
  }

  void backspace() {
    if (state.busy || state.code.isEmpty) return;
    final code = state.code.substring(0, state.code.length - 1);
    state = state.copyWith(code: code, wrongCode: false);
    if (code.isEmpty) _armNotAtGate();
  }

  /// "Confirm delivery" → Handover 05 → delivered, 04 or 10. Never locks: a code
  /// that keeps failing leads to Handover 13.
  Future<void> confirmCode() => _run((order) async {
    final outcome = await ref.read(completeHandoverUseCaseProvider).byCode(_uid, order, state.code, _items(order));
    if (ref.mounted) await _after(outcome);
  });

  /// "Code not working? Check order details" → Handover 13.
  void checkDetails() => state = state.copyWith(step: HandoverStep.details);

  /// "Details match, hand over".
  Future<void> detailsMatch() => _run((order) async {
    final outcome = await ref.read(completeHandoverUseCaseProvider).byDetails(_uid, order, _items(order));
    if (ref.mounted) await _after(outcome);
  });

  /// "I've collected ₹149".
  Future<void> collected() => _run((order) async {
    final outcome = await ref.read(completeHandoverUseCaseProvider).byCash(_uid, order, _items(order));
    if (ref.mounted) await _after(outcome);
  });

  List<OrderItem> _items(DeliveryOrder order) => handedOverItems(order, state.quantitiesOf(order));

  Future<void> _after(HandoverOutcome outcome) async {
    switch (outcome) {
      case HandoverOutcome.delivered:
        // The order's status takes over: Handover 06 or 11.
        break;
      case HandoverOutcome.wrongCode:
        state = state.copyWith(step: HandoverStep.code, wrongCode: true);
      case HandoverOutcome.savedOffline:
        await _toSaved();
    }
  }

  // ── Handover 07 ──

  /// The flow map's "Not at gate": the customer is told, the clock starts.
  void notAtGate() {
    final order = _order;
    if (order == null) return;
    ref.read(notifyCustomerWaitingUseCaseProvider)(order);
    state = state.copyWith(
      step: HandoverStep.waiting,
      waitingSince: state.waitingSince ?? ref.read(clockProvider)(),
    );
  }

  // ── Handover 10 ──

  Future<void> _toSaved() async {
    final local = await ref.read(loadHandoverLocalUseCaseProvider)(_uid);
    if (ref.mounted) state = state.copyWith(step: HandoverStep.saved, local: local);
  }

  /// Signal's back while still at the gate: the flow map's "Back online". What
  /// was saved goes through now, and a code that's wrong can still be fixed.
  Future<void> _backOnline() async {
    // Once the rider has left the gate, it syncs by itself instead.
    if (state.step != HandoverStep.saved || state.busy || _leftGate) return;
    final order = _order;
    if (order == null) return;
    final saved = state.local.savedFor(order.id);
    final complete = ref.read(completeHandoverUseCaseProvider);
    await _run((order) async {
      final items = saved?.items ?? _items(order);
      switch (saved?.proof) {
        case HandoverProof.code:
          await _after(await complete.byCode(_uid, order, saved!.code ?? '', items));
        case HandoverProof.cash:
          await _after(await complete.byCash(_uid, order, items));
        case HandoverProof.details:
          await _after(await complete.byDetails(_uid, order, items));
        case HandoverProof.none || null:
          await ref.read(forgetSavedHandoverUseCaseProvider)(_uid, order.id);
          if (ref.mounted) _toPayment(order, from: HandoverStep.quantity);
      }
    });
  }

  /// "Back to waiting" → the map; it syncs by itself.
  Future<void> backToWaiting() => _run((order) async {
    final shift = ref.read(todayShiftProvider).value;
    if (shift == null) return;
    _leftGate = true;
    await ref.read(finishSavedHandoverUseCaseProvider)(_uid, shift, order.id);
  });
}

final handoverViewModelProvider = NotifierProvider<HandoverViewModel, HandoverState>(HandoverViewModel.new);
