import 'dart:async';

import '../../../../core/config/demo_data.dart';
import '../../../refill/domain/entities/restock.dart';
import '../../domain/entities/online_status.dart';
import '../../domain/repositories/online_repository.dart';

/// In-memory online status for demo mode. The demo pill on the main map plays
/// the backend through [set].
class DemoOnlineRepository implements OnlineRepository {
  DemoOnlineRepository(this._clock);

  final DateTime Function() _clock;
  final _changes = StreamController<OnlineStatus>.broadcast();
  OnlineStatus _status = const OnlineStatus();

  OnlineStatus get status => _status;

  /// What the backend would do.
  void set(OnlineStatus status) {
    _status = status;
    _changes.add(status);
  }

  /// Called when the rider finishes an order and heads back to the spot.
  void Function()? onOrderFinished;

  /// The order queue from the design (Shift 28). The clock of the first one
  /// starts now; a queued order's when it reaches the front.
  List<AssignedOrder> get sampleQueue => [
    for (final (i, (number, gate, items, cash)) in DemoData.orderQueue.indexed)
      AssignedOrder(
        id: number,
        number: number,
        gate: gate,
        items: items,
        collectCash: cash,
        assignedAt: i == 0 ? _clock() : null,
        place: DemoData.orderPlace,
      ),
  ];

  @override
  Stream<OnlineStatus> watch(String uid, String shiftId) async* {
    yield _status;
    yield* _changes.stream;
  }

  @override
  Future<void> markOnline(String uid, String shiftId) async => set(_status.copyWith(onlineAt: _clock()));

  @override
  Future<void> setShiftEnd(String uid, String shiftId, DateTime end) async {
    await Future<void>.delayed(DemoData.addingTime);
    set(_status.copyWith(shiftEnd: () => end));
  }

  @override
  Future<void> startOrder(String uid, String shiftId, AssignedOrder order) async =>
      set(_status.copyWith(activeOrderId: () => order.id));

  @override
  Future<void> finishOrder(String uid, String shiftId, String orderId, {String? thenStart}) async {
    final left = _status.queue.where((o) => o.id != orderId).toList();
    if (left.isNotEmpty && left.first.assignedAt == null) left[0] = left.first.withAssignedAt(_clock());
    set(_status.copyWith(queue: left, activeOrderId: () => thenStart));
    onOrderFinished?.call();
  }

  @override
  Future<void> setBreak(String uid, String shiftId, BreakState? state) async => set(_status.copyWith(breakState: () => state));

  @override
  Future<void> setNudge(String uid, String shiftId, RelocationNudge? nudge) async => set(_status.copyWith(nudge: () => nudge));

  /// The hub's side of a confirmed restock, as Restock 03 draws it.
  @override
  Future<void> setRestock(String uid, String shiftId, RestockRequest? restock) async {
    final now = _clock();
    set(
      _status.copyWith(
        restock: () => restock != null && restock.stage == RestockStage.inProgress && restock.queueSlot == null
            ? RestockRequest(
                stage: restock.stage,
                hubName: restock.hubName,
                lines: restock.lines,
                queueSlot: DemoData.restockQueueSlot,
                arriveBy: now.add(DemoData.restockArriveIn),
                packing: HubPacking.packing,
                readyAt: now.add(DemoData.restockPackedIn),
              )
            : restock,
      ),
    );
  }

  @override
  Future<void> addStock(String uid, String shiftId, int portions) async =>
      set(_status.copyWith(stockAdded: _status.stockAdded + portions, itemsLeft: const []));

  /// A cancelled trip's pay; the food stays on the scooter.
  void addTripPay(int rupees) => set(_status.copyWith(earned: _status.earned + rupees));

  /// What the backend does on delivery. Only what the customer got leaves the
  /// scooter.
  void countDelivered(int portions, double earned) => set(
    _status.copyWith(
      orders: _status.orders + 1,
      earned: _status.earned + earned,
      sold: _status.sold + portions,
      averageDeliverySeconds: () => DemoData.averageDeliverySeconds,
    ),
  );

  void dispose() => _changes.close();
}
