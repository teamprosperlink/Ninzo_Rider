import 'delivery_order.dart';
import 'order.dart';

/// How the handover was proved. There's no lockout: a code that doesn't work
/// falls back on checking the order's details (Handover 13).
enum HandoverProof {
  /// UPI: the customer's 4-digit code; only the backend can check it.
  code,

  /// Cash on delivery: the rider collected the amount. Cash orders have no code.
  cash,

  /// UPI: the code didn't work and the rider checked the number and items on
  /// the customer's order screen.
  details,

  /// Saved without signal before any of the above (Handover 09 → 10).
  none,
}

/// What a confirmation led to.
enum HandoverOutcome {
  /// Handover 06 or 11.
  delivered,

  /// Handover 04.
  wrongCode,

  /// Handover 10: no signal, it's on the phone.
  savedOffline,
}

/// What the rider sends for an order they hand over with signal.
class HandoverRequest {
  const HandoverRequest({required this.orderId, required this.proof, required this.items, this.code});

  final String orderId;
  final HandoverProof proof;

  /// What the customer got, which can be less than what they ordered.
  final List<OrderItem> items;

  /// What the rider typed, for [HandoverProof.code].
  final String? code;
}

/// A handover saved on the phone without signal (Handover 10), with what it
/// takes to count it once it syncs.
class SavedHandover {
  const SavedHandover({
    required this.orderId,
    required this.number,
    required this.gateName,
    required this.proof,
    required this.items,
    required this.payment,
    required this.amount,
    required this.riderFee,
    required this.assignedAt,
    required this.savedAt,
    this.gateConfirmedAt,
    this.code,
    this.released = false,
  });

  factory SavedHandover.of(
    DeliveryOrder order, {
    required HandoverProof proof,
    required List<OrderItem> items,
    required DateTime at,
    String? code,
  }) => SavedHandover(
    orderId: order.id,
    number: order.number,
    gateName: order.gate.name,
    proof: proof,
    items: items,
    payment: order.payment,
    amount: order.amount,
    riderFee: order.riderFee,
    assignedAt: order.assignedAt,
    gateConfirmedAt: order.gateConfirmedAt,
    savedAt: at,
    code: code,
  );

  final String orderId;
  final String number;
  final String gateName;
  final HandoverProof proof;
  final List<OrderItem> items;
  final OrderPayment payment;
  final int amount;
  final int riderFee;
  final DateTime assignedAt;
  final DateTime? gateConfirmedAt;
  final DateTime savedAt;

  /// What the rider typed; the backend checks it after the sync.
  final String? code;

  /// "Back to waiting": the rider has left the gate, so it syncs by itself
  /// as soon as there's signal. Until then signal returning brings the rider
  /// back to the handover.
  final bool released;

  /// Portions that left the scooter.
  int get portions => items.fold(0, (sum, i) => sum + i.quantity);

  SavedHandover asReleased() => SavedHandover(
    orderId: orderId,
    number: number,
    gateName: gateName,
    proof: proof,
    items: items,
    payment: payment,
    amount: amount,
    riderFee: riderFee,
    assignedAt: assignedAt,
    gateConfirmedAt: gateConfirmedAt,
    savedAt: savedAt,
    code: code,
    released: true,
  );
}

/// The phone's copy: what waits to sync, and when the last sync was.
class HandoverLocalState {
  const HandoverLocalState({this.saved = const [], this.lastSync});

  final List<SavedHandover> saved;
  final DateTime? lastSync;

  SavedHandover? savedFor(String orderId) => saved.where((s) => s.orderId == orderId).firstOrNull;

  HandoverLocalState withSaved(SavedHandover handover) =>
      HandoverLocalState(saved: [...without(handover.orderId).saved, handover], lastSync: lastSync);

  HandoverLocalState without(String orderId) =>
      HandoverLocalState(saved: saved.where((s) => s.orderId != orderId).toList(), lastSync: lastSync);

  HandoverLocalState syncedAt(DateTime at) => HandoverLocalState(saved: saved, lastSync: at);
}

