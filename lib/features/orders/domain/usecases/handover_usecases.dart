import 'dart:async';

import '../../../../core/error/app_exception.dart';
import '../../../online/domain/entities/online_status.dart';
import '../../../online/domain/repositories/online_repository.dart';
import '../../../online/domain/usecases/online_usecases.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../../stock/domain/repositories/stock_repository.dart';
import '../entities/delivery_order.dart';
import '../entities/handover.dart';
import '../entities/order.dart' show OrderItem;
import '../entities/problem_report.dart';
import '../repositories/delivery_repository.dart';
import '../repositories/handover_repository.dart';

abstract final class HandoverRules {
  static const codeLength = 4;

  /// On the code step with nothing typed for this long, the rider is offered
  /// "Customer not at the gate?" (the flow map's "Not at gate").
  static const notAtGateAfter = Duration(seconds: 15);

  static final _code = RegExp(r'^\d{4}$');
}

/// The customer code is for UPI orders only; cash orders go straight to
/// Collect cash (Handover 02, 12).
bool takesCode(DeliveryOrder order) => order.payment == OrderPayment.upi;

/// Handover 01: every item and the sealed bag.
int packChecksOf(DeliveryOrder order) => order.items.length + 1;

bool isPacked(DeliveryOrder order, Set<int> ticked) => ticked.length == packChecksOf(order);

/// Handover 01 offers the quantity check while an item can't be ticked yet.
bool anyItemUnticked(DeliveryOrder order, Set<int> ticked) =>
    Iterable.generate(order.items.length).any((i) => !ticked.contains(i));

/// What was ordered, as Handover 08 starts.
List<int> orderedQuantities(DeliveryOrder order) => [for (final item in order.items) item.quantity];

/// What the customer gets. The rider can only lower a number; at least one
/// item has to change hands (otherwise it's a problem to report).
List<OrderItem> handedOverItems(DeliveryOrder order, List<int> quantities) => [
  for (final (i, item) in order.items.indexed)
    if (quantities[i] > 0) OrderItem(name: item.name, quantity: quantities[i]),
];

bool isPartial(DeliveryOrder order, List<int> quantities) {
  for (final (i, item) in order.items.indexed) {
    if (quantities[i] != item.quantity) return true;
  }
  return false;
}

/// Handover 09's note, null when nothing changed.
String? partialNoteOf(DeliveryOrder order, List<int> quantities) {
  final changed = [
    for (final (i, item) in order.items.indexed)
      if (quantities[i] != item.quantity) (item, quantities[i]),
  ];
  if (changed.isEmpty) return null;
  final String what;
  if (changed.length == 1) {
    final (item, handed) = changed.single;
    what = '$handed of ${item.quantity} ${item.name}${item.quantity == 1 ? '' : 's'}';
  } else {
    final handed = quantities.fold(0, (sum, q) => sum + q);
    what = '$handed of ${order.itemCount} items';
  }
  return 'You’re handing over $what. We’ll note the change on this order.';
}

/// "Time to gate" and "Delivered in" (Handover 06, 11): whole seconds from
/// assignment to the confirmed gate.
int secondsToGateOf(DeliveryOrder order) {
  final at = order.gateConfirmedAt;
  if (at == null) return 0;
  final seconds = at.difference(order.assignedAt).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

/// The order after [orderId], null when none is waiting: Handover 11 or 06.
AssignedOrder? nextOrderOf(OnlineStatus status, String orderId) =>
    visibleOrders(status).where((o) => o.id != orderId).firstOrNull;

/// Hands the order over: by the customer's code (UPI), by collecting the cash
/// (cash), or by the order's details when the code doesn't work (UPI, no
/// lockout). Without signal it's saved on the phone (Handover 10). Riders can't
/// read the code: the backend checks it.
class CompleteHandover {
  const CompleteHandover(this._repository, this._store, this._signal, this._clock);

  final DeliveryRepository _repository;
  final HandoverStore _store;
  final SignalRepository _signal;
  final DateTime Function() _clock;

  Future<HandoverOutcome> byCode(String uid, DeliveryOrder order, String code, List<OrderItem> items) async {
    if (!takesCode(order)) throw const AppException();
    // Can't be right, and doesn't go to the backend.
    if (!HandoverRules._code.hasMatch(code)) return HandoverOutcome.wrongCode;
    return _complete(uid, order, HandoverProof.code, items, code);
  }

  Future<HandoverOutcome> byCash(String uid, DeliveryOrder order, List<OrderItem> items) async {
    if (takesCode(order)) throw const AppException();
    return _complete(uid, order, HandoverProof.cash, items, null);
  }

  Future<HandoverOutcome> byDetails(String uid, DeliveryOrder order, List<OrderItem> items) async {
    if (!takesCode(order)) throw const AppException();
    return _complete(uid, order, HandoverProof.details, items, null);
  }

  Future<HandoverOutcome> _complete(
    String uid,
    DeliveryOrder order,
    HandoverProof proof,
    List<OrderItem> items,
    String? code,
  ) async {
    if (!await _signal.isOnline()) return _save(uid, order, proof, items, code);
    final bool done;
    try {
      done = await _repository.completeHandover(
        HandoverRequest(orderId: order.id, proof: proof, items: items, code: code),
      );
    } on TimeoutException {
      // The phone says there's a network, but nothing gets through.
      return _save(uid, order, proof, items, code);
    }
    final local = await _store.load(uid);
    await _store.save(uid, done ? local.without(order.id).syncedAt(_clock()) : local.without(order.id));
    return done ? HandoverOutcome.delivered : HandoverOutcome.wrongCode;
  }

  Future<HandoverOutcome> _save(
    String uid,
    DeliveryOrder order,
    HandoverProof proof,
    List<OrderItem> items,
    String? code,
  ) async {
    final local = await _store.load(uid);
    await _store.save(
      uid,
      local.withSaved(SavedHandover.of(order, proof: proof, items: items, at: _clock(), code: code)),
    );
    return HandoverOutcome.savedOffline;
  }
}

/// "Continue to code" (Handover 08, 09). A changed quantity has to reach the
/// order, so without signal it's saved first (Handover 09 → 10). Returns
/// whether it was saved; nothing to save without a change.
class SaveQuantities {
  const SaveQuantities(this._store, this._signal, this._clock);

  final HandoverStore _store;
  final SignalRepository _signal;
  final DateTime Function() _clock;

  Future<bool> call(String uid, DeliveryOrder order, List<int> quantities) async {
    final items = handedOverItems(order, quantities);
    if (items.isEmpty) throw const AppException();
    if (!isPartial(order, quantities) || await _signal.isOnline()) return false;
    final local = await _store.load(uid);
    await _store.save(uid, local.withSaved(SavedHandover.of(order, proof: HandoverProof.none, items: items, at: _clock())));
    return true;
  }
}

/// What Handover 10 shows.
class LoadHandoverLocal {
  const LoadHandoverLocal(this._store);

  final HandoverStore _store;

  Future<HandoverLocalState> call(String uid) => _store.load(uid);
}

/// Signal came back while the rider is still at the gate: it carries on online
/// and the saved copy is dropped (Handover 10 → 02).
class ForgetSavedHandover {
  const ForgetSavedHandover(this._store);

  final HandoverStore _store;

  Future<void> call(String uid, String orderId) async => _store.save(uid, (await _store.load(uid)).without(orderId));
}

/// Sends what the rider left behind at a gate without signal, oldest first.
/// What fails stays on the phone for the next time signal returns.
class SyncSavedHandovers {
  SyncSavedHandovers(this._repository, this._store, this._clock);

  final DeliveryRepository _repository;
  final HandoverStore _store;
  final DateTime Function() _clock;
  bool _running = false;

  /// How many were sent.
  Future<int> call(String uid) async {
    if (_running) return 0;
    _running = true;
    var sent = 0;
    try {
      var local = await _store.load(uid);
      for (final saved in local.saved.where((s) => s.released).toList()) {
        await _repository.syncSavedHandover(saved);
        local = local.without(saved.orderId).syncedAt(_clock());
        await _store.save(uid, local);
        sent++;
      }
    } catch (_) {
      // Tried again the next time signal returns.
    } finally {
      _running = false;
    }
    return sent;
  }
}

/// "Back to waiting" on Handover 10: the rider leaves the gate and the saved
/// handover syncs by itself once there's signal.
class FinishSavedHandover {
  const FinishSavedHandover(this._store, this._online, this._sync, this._signal);

  final HandoverStore _store;
  final OnlineRepository _online;
  final SyncSavedHandovers _sync;
  final SignalRepository _signal;

  Future<void> call(String uid, Shift shift, String orderId) async {
    final local = await _store.load(uid);
    final saved = local.savedFor(orderId);
    if (saved != null) await _store.save(uid, local.withSaved(saved.asReleased()));
    // Firestore only finishes this write once there's signal, and its cache
    // already shows it; the rider doesn't wait.
    unawaited(_online.finishOrder(uid, shift.id, orderId).catchError((Object _) {}));
    if (await _signal.isOnline()) await _sync(uid);
  }
}

/// "Start next order" (Handover 11 → Order 02): the rider is off straight away.
class StartNextOrder {
  const StartNextOrder(this._online, this._delivery);

  final OnlineRepository _online;
  final DeliveryRepository _delivery;

  Future<void> call(String uid, Shift shift, OnlineStatus status, String orderId) async {
    final next = nextOrderOf(status, orderId);
    await _online.finishOrder(uid, shift.id, orderId, thenStart: next?.id);
    if (next != null) await _delivery.startNavigation(next.id);
  }
}

/// Handover 07: tells the customer the rider is waiting. Best effort.
class NotifyCustomerWaiting {
  const NotifyCustomerWaiting(this._repository);

  final DeliveryRepository _repository;

  void call(DeliveryOrder order) => unawaited(_repository.notifyCustomerWaiting(order.id).catchError((Object _) {}));
}

/// "Send report" (Problem 02 → 03). It needs signal to reach anyone.
class SendProblemReport {
  const SendProblemReport(this._repository, this._signal, this._clock);

  final ProblemReportRepository _repository;
  final SignalRepository _signal;
  final DateTime Function() _clock;

  Future<void> call(String uid, String? orderId, ProblemKind? kind) async {
    if (kind == null) throw const AppException();
    if (!await _signal.isOnline()) throw const AppException();
    await _repository.send(ProblemReport(riderId: uid, orderId: orderId, kind: kind, at: _clock()));
  }
}
