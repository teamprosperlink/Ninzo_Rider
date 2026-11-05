import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ninzo_rider/features/orders/presentation/viewmodels/handover_view_model.dart';
import 'package:ninzo_rider/core/error/app_exception.dart';
import 'package:ninzo_rider/features/intro/domain/entities/app_permission.dart';
import 'package:ninzo_rider/features/online/domain/entities/online_status.dart';
import 'package:ninzo_rider/features/online/data/repositories/demo_online_repository.dart';
import 'package:ninzo_rider/features/online/data/repositories/demo_rider_location.dart';
import 'package:ninzo_rider/features/orders/data/models/delivery_order_model.dart';
import 'package:ninzo_rider/features/orders/data/repositories/demo_delivery_repository.dart';
import 'package:ninzo_rider/features/orders/data/repositories/demo_order_repository.dart';
import 'package:ninzo_rider/features/orders/data/repositories/local_handover_stores.dart';
import 'package:ninzo_rider/features/orders/domain/entities/delivery_order.dart';
import 'package:ninzo_rider/features/orders/domain/entities/handover.dart';
import 'package:ninzo_rider/features/orders/domain/entities/order.dart' show OrderItem;
import 'package:ninzo_rider/features/orders/domain/entities/problem_report.dart';
import 'package:ninzo_rider/features/orders/domain/usecases/handover_usecases.dart';
import 'package:ninzo_rider/features/orders/presentation/viewmodels/problem_report_view_model.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift.dart';

import 'fakes.dart';

void main() {
  final assigned = DateTime(2026, 1, 1, 10);
  final now = assigned.add(const Duration(minutes: 2));
  final gateAt = assigned.add(const Duration(seconds: 72));

  DeliveryOrder upi() => testDeliveryOrder(assignedAt: assigned, status: DeliveryStatus.atGate, gateConfirmedAt: gateAt);
  DeliveryOrder cash() => testDeliveryOrder(
    assignedAt: assigned,
    status: DeliveryStatus.atGate,
    payment: OrderPayment.cash,
    amount: 149,
    gateConfirmedAt: gateAt,
  );

  group('Rules', () {
    test('the code is for UPI only', () {
      expect(takesCode(upi()), isTrue);
      expect(takesCode(cash()), isFalse);
    });

    test('packing takes every item and the bag', () {
      final order = upi();
      expect(packChecksOf(order), 3);
      expect(isPacked(order, {0, 1}), isFalse);
      expect(isPacked(order, {0, 1, 2}), isTrue);
      expect(anyItemUnticked(order, {0}), isTrue);
      expect(anyItemUnticked(order, {0, 1}), isFalse);
    });

    test('partial quantities: the note and what changes hands', () {
      final order = upi();
      expect(partialNoteOf(order, [2, 1]), isNull);
      expect(isPartial(order, [2, 1]), isFalse);
      expect(
        partialNoteOf(order, [1, 1]),
        'You’re handing over 1 of 2 Smash Burgers. We’ll note the change on this order.',
      );
      expect(partialNoteOf(order, [1, 0]), startsWith('You’re handing over 1 of 3 items.'));
      expect(partialNoteOf(order, [2, 0]), startsWith('You’re handing over 0 of 1 Paneer Tikka Wrap.'));
      final items = handedOverItems(order, [1, 0]);
      expect(items.single.name, 'Smash Burger');
      expect(items.single.quantity, 1);
    });

    test('time to gate runs from the assignment', () {
      expect(secondsToGateOf(upi()), 72);
      expect(secondsToGateOf(testDeliveryOrder(assignedAt: assigned)), 0);
    });

    test('the next order is the one after this', () {
      const a = AssignedOrder(id: 'a', number: 'a', gate: 'G', items: 1);
      const b = AssignedOrder(id: 'b', number: 'b', gate: 'G', items: 1);
      expect(nextOrderOf(const OnlineStatus(queue: [a, b]), 'a')?.id, 'b');
      expect(nextOrderOf(const OnlineStatus(queue: [a]), 'a'), isNull);
    });
  });

  group('CompleteHandover', () {
    late FakeDeliveryRepository repository;
    late InMemoryHandoverStore store;
    late FakeSignal signal;
    late CompleteHandover complete;
    const items = [OrderItem(name: 'Smash Burger', quantity: 2)];

    setUp(() {
      repository = FakeDeliveryRepository()..order.value = upi();
      store = InMemoryHandoverStore();
      signal = FakeSignal();
      complete = CompleteHandover(repository, store, signal, () => now);
    });

    test('a right code delivers; a wrong one never locks', () async {
      for (var i = 0; i < 6; i++) {
        expect(await complete.byCode('u1', upi(), '1111', items), HandoverOutcome.wrongCode);
      }
      expect(await complete.byCode('u1', upi(), testCustomerCode, items), HandoverOutcome.delivered);
      expect(repository.handovers.single.proof, HandoverProof.code);
      expect((await store.load('u1')).lastSync, now);
    });

    test('a code that can\'t be right stays on the phone', () async {
      expect(await complete.byCode('u1', upi(), '12', items), HandoverOutcome.wrongCode);
      expect(repository.handovers, isEmpty);
    });

    test('cash has no code, UPI collects none', () async {
      expect(() => complete.byCode('u1', cash(), '1234', items), throwsA(isA<AppException>()));
      expect(() => complete.byCash('u1', upi(), items), throwsA(isA<AppException>()));
      expect(() => complete.byDetails('u1', cash(), items), throwsA(isA<AppException>()));
      repository.order.value = cash();
      expect(await complete.byCash('u1', cash(), items), HandoverOutcome.delivered);
      expect(repository.handovers.single.proof, HandoverProof.cash);
    });

    test('details hand over a UPI order when the code fails', () async {
      expect(await complete.byDetails('u1', upi(), items), HandoverOutcome.delivered);
      expect(repository.handovers.single.proof, HandoverProof.details);
    });

    test('without signal it is saved, and the code is not checked', () async {
      signal.online = false;
      expect(await complete.byCode('u1', upi(), '1111', items), HandoverOutcome.savedOffline);
      expect(repository.handovers, isEmpty);
      final saved = (await store.load('u1')).savedFor('A2931')!;
      expect(saved.proof, HandoverProof.code);
      expect(saved.code, '1111');
      expect(saved.released, isFalse);
    });

    test('online again, the outcome replaces what was saved', () async {
      signal.online = false;
      await complete.byCode('u1', upi(), testCustomerCode, items);
      signal.online = true;
      await complete.byCode('u1', upi(), testCustomerCode, items);
      expect((await store.load('u1')).saved, isEmpty);
    });
  });

  group('Saved handovers', () {
    late FakeDeliveryRepository repository;
    late InMemoryHandoverStore store;
    late FakeSignal signal;
    late FakeOnlineRepository online;
    late SyncSavedHandovers sync;

    setUp(() {
      repository = FakeDeliveryRepository()..order.value = upi();
      store = InMemoryHandoverStore();
      signal = FakeSignal();
      online = FakeOnlineRepository()
        ..status.value = const OnlineStatus(
          activeOrderId: 'A2931',
          queue: [AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', items: 2)],
        );
      sync = SyncSavedHandovers(repository, store, () => now);
    });

    test('a changed quantity is saved without signal, not with it', () async {
      final save = SaveQuantities(store, signal, () => now);
      expect(await save('u1', upi(), [1, 1]), isFalse);
      signal.online = false;
      expect(await save('u1', upi(), [2, 1]), isFalse, reason: 'nothing changed');
      expect(await save('u1', upi(), [1, 1]), isTrue);
      expect((await store.load('u1')).savedFor('A2931')!.proof, HandoverProof.none);
      expect(() => save('u1', upi(), [0, 0]), throwsA(isA<AppException>()));
    });

    test('only what the rider left behind syncs; what fails stays', () async {
      await store.save(
        'u1',
        HandoverLocalState(saved: [SavedHandover.of(upi(), proof: HandoverProof.cash, items: const [], at: now)]),
      );
      expect(await sync('u1'), 0, reason: 'still at the gate');

      final finish = FinishSavedHandover(store, online, sync, signal);
      signal.online = false;
      final shift = testShift(phase: ShiftPhase.online);
      await finish('u1', shift, 'A2931');
      expect(online.status.value.activeOrderId, isNull);
      expect(repository.synced, isEmpty);
      expect((await store.load('u1')).saved.single.released, isTrue);

      repository.failSync = true;
      expect(await sync('u1'), 0);
      expect((await store.load('u1')).saved, hasLength(1));

      repository.failSync = false;
      expect(await sync('u1'), 1);
      final local = await store.load('u1');
      expect(local.saved, isEmpty);
      expect(local.lastSync, now);
      expect(repository.synced.single.orderId, 'A2931');
    });

    test('survives on the phone', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsHandoverStore();
      final saved = SavedHandover.of(
        upi(),
        proof: HandoverProof.code,
        code: '4829',
        items: const [OrderItem(name: 'Smash Burger', quantity: 1)],
        at: now,
      ).asReleased();
      await prefs.save('u1', HandoverLocalState(saved: [saved], lastSync: gateAt));
      final local = await prefs.load('u1');
      final back = local.savedFor('A2931')!;
      expect(local.lastSync, gateAt);
      expect(back.code, '4829');
      expect(back.released, isTrue);
      expect(back.portions, 1);
      expect(back.gateConfirmedAt, gateAt);
      expect(back.riderFee, 40);
    });

    test('start next moves straight on to the next order', () async {
      online.status.value = const OnlineStatus(
        activeOrderId: 'A2931',
        queue: [
          AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', items: 2),
          AssignedOrder(id: 'A2934', number: 'A2934', gate: 'Gate 5', items: 1),
        ],
      );
      await StartNextOrder(online, repository)('u1', testShift(phase: ShiftPhase.online), online.status.value, 'A2931');
      expect(online.status.value.activeOrderId, 'A2934');
      expect(online.status.value.queue.single.id, 'A2934');
      expect(repository.order.value?.status, DeliveryStatus.onTheWay);
    });
  });

  group('Delivery history', () {
    test('a new-flow delivery reads as a history order', () {
      final order = DeliveryOrderModel.historyOrder('o1', {
        'orderNumber': 'A2931',
        'riderId': 'u1',
        'gate': {'name': 'Gate 3', 'landmark': 'Main entrance', 'lat': 13.0, 'lng': 77.0},
        'items': [
          {'name': 'Smash Burger', 'qty': 2},
        ],
        'handedOver': [
          {'name': 'Smash Burger', 'qty': 1},
        ],
        'payment': 'cash',
        'amount': 149,
        'riderFee': 40,
        'status': 'delivered',
      });
      expect(order.orderNumber, 'A2931');
      expect(order.restaurant.name, 'Gate 3');
      expect(order.itemCount, 1);
      expect(order.collectCash, isTrue);
      expect(order.riderFee, 40);
    });

    test('the demo counts a delivery: stats, stock and history', () async {
      final online = DemoOnlineRepository(() => now);
      online.set(OnlineStatus(queue: online.sampleQueue, activeOrderId: 'A2931'));
      final history = DemoOrderRepository();
      final demo = DemoDeliveryRepository(() => now, online, DemoRiderLocation(), null, history);
      await demo.watchOrder('A2931').first;

      expect(
        await demo.completeHandover(
          const HandoverRequest(orderId: 'A2931', proof: HandoverProof.code, code: '4821', items: []),
        ),
        isFalse,
      );
      expect(online.status.orders, 0);

      expect(
        await demo.completeHandover(
          const HandoverRequest(
            orderId: 'A2931',
            proof: HandoverProof.code,
            code: '4829',
            items: [OrderItem(name: 'Smash Burger', quantity: 2), OrderItem(name: 'Paneer Tikka Wrap', quantity: 1)],
          ),
        ),
        isTrue,
      );
      expect(online.status.orders, 1);
      expect(online.status.earned, 40);
      expect(online.status.sold, 3);
      expect((await history.watchHistory('u1').first).single.orderNumber, 'A2931');

      await demo.syncSavedHandover(
        SavedHandover.of(
          testDeliveryOrder(assignedAt: assigned),
          proof: HandoverProof.none,
          items: const [OrderItem(name: 'Cold Coffee', quantity: 1)],
          at: now,
        ),
      );
      expect(online.status.orders, 2);
      expect(online.status.sold, 4);
      expect((await history.watchHistory('u1').first), hasLength(2));
    });
  });

  group('SendProblemReport', () {
    test('needs a choice and signal', () async {
      final reports = FakeProblemReports();
      final signal = FakeSignal();
      final send = SendProblemReport(reports, signal, () => now);
      expect(() => send('u1', 'A2931', null), throwsA(isA<AppException>()));
      signal.online = false;
      expect(() => send('u1', 'A2931', ProblemKind.accident), throwsA(isA<AppException>()));
      signal.online = true;
      await send('u1', 'A2931', ProblemKind.accident);
      expect(reports.sent.single.kind, ProblemKind.accident);
      expect(reports.sent.single.riderId, 'u1');
    });
  });

  group('Screens', () {
    Fakes rider({OrderPayment payment = OrderPayment.upi, List<AssignedOrder>? queue}) {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.now = now;
      fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.online, scanned: 6);
      fakes.permissions.status[AppPermission.camera] = PermissionResult.granted;
      fakes.delivery.order.value = testDeliveryOrder(
        assignedAt: assigned,
        status: DeliveryStatus.atGate,
        payment: payment,
        amount: payment == OrderPayment.cash ? 149 : 60,
        gateConfirmedAt: gateAt,
      );
      fakes.online.status.value = OnlineStatus(
        activeOrderId: 'A2931',
        queue: queue ?? const [AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', items: 2)],
      );
      return fakes;
    }

    Future<void> tap(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text).last);
      await tester.tap(find.text(text).last);
      await settle(tester);
    }

    Future<void> setSize(WidgetTester tester) async {
      tester.view
        // Wide: the test font's letters are much wider than Inter's.
        ..physicalSize = const Size(2400, 4200)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> toCode(WidgetTester tester, Fakes fakes) async {
      await setSize(tester);
      await pumpApp(tester, fakes);
      await tap(tester, 'Hand over order');
      expect(find.text('Pack order #A2931'), findsOneWidget);
      await tap(tester, 'Smash Burger × 2');
      await tap(tester, 'Paneer Tikka Wrap × 1');
      // Not packed yet: the button does nothing.
      await tap(tester, 'Packed – go');
      expect(find.text('Pack order #A2931'), findsOneWidget);
      await tap(tester, 'Bag sealed');
      expect(find.text('Tick all items to continue'), findsNothing);
      await tap(tester, 'Packed – go');
    }

    Future<void> type(WidgetTester tester, String code) async {
      for (final digit in code.split('')) {
        await tap(tester, digit);
      }
    }

    testWidgets('UPI: wrong code, right code, back to waiting', (tester) async {
      final fakes = rider();
      await toCode(tester, fakes);
      expect(find.text('Ask for the customer’s code'), findsOneWidget);

      await tap(tester, 'Confirm delivery');
      expect(fakes.delivery.handovers, isEmpty, reason: 'nothing typed yet');

      await type(tester, '4821');
      await tap(tester, 'Confirm delivery');
      expect(find.textContaining('Almost there!'), findsOneWidget);
      expect(find.text('Code not working? Check order details'), findsOneWidget);

      await type(tester, '4');
      expect(find.textContaining('Almost there!'), findsNothing);
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      await type(tester, '4829');
      await tap(tester, 'Confirm delivery');
      expect(find.text('Delivered in 1:12'), findsOneWidget);
      expect(find.text('Items left on scooter'), findsOneWidget);
      expect(find.text('₹40'), findsOneWidget);

      await tap(tester, 'Back to waiting');
      expect(fakes.online.status.value.activeOrderId, isNull);
      expect(fakes.online.status.value.queue, isEmpty);
    });

    testWidgets('Cash: straight to Collect cash, no code', (tester) async {
      final fakes = rider(payment: OrderPayment.cash);
      await toCode(tester, fakes);
      expect(find.text('Collect ₹149'), findsOneWidget);
      await tap(tester, 'I’ve collected ₹149');
      expect(fakes.delivery.handovers.single.proof, HandoverProof.cash);
      expect(find.text('Delivered in 1:12'), findsOneWidget);
    });

    testWidgets('Delivered with another order: start next → on the way', (tester) async {
      final fakes = rider(
        queue: const [
          AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', items: 2),
          AssignedOrder(id: 'A2934', number: 'A2934', gate: 'Gate 5', items: 1, collectCash: 149),
        ],
      );
      await toCode(tester, fakes);
      await type(tester, '4829');
      await tap(tester, 'Confirm delivery');
      expect(find.text('Next · #A2934 · Gate 5'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      await tap(tester, 'Start next order');
      expect(fakes.online.status.value.activeOrderId, 'A2934');
      expect(fakes.delivery.order.value?.status, DeliveryStatus.onTheWay);
    });

    testWidgets('No signal: saved, signal back resumes; a wrong code can be fixed', (tester) async {
      final fakes = rider();
      await toCode(tester, fakes);
      await type(tester, '1111');
      fakes.signal.online = false;
      await settle(tester);
      await tap(tester, 'Confirm delivery');
      expect(find.text('Handover saved'), findsOneWidget);
      expect(find.text('1 event'), findsOneWidget);

      fakes.signal.online = true;
      await settle(tester);
      expect(find.textContaining('Almost there!'), findsOneWidget);
      expect((await fakes.handoverStore.load('u1')).saved, isEmpty);
    });

    testWidgets('No signal: back to waiting, then it syncs by itself', (tester) async {
      final fakes = rider();
      await toCode(tester, fakes);
      await type(tester, '4829');
      fakes.signal.online = false;
      await settle(tester);
      await tap(tester, 'Confirm delivery');
      await tap(tester, 'Back to waiting');
      expect(fakes.online.status.value.activeOrderId, isNull);
      expect(fakes.delivery.synced, isEmpty);

      fakes.signal.online = true;
      await settle(tester);
      expect(fakes.delivery.synced.single.code, '4829');
      expect((await fakes.handoverStore.load('u1')).saved, isEmpty);
    });

    testWidgets('Quantity without signal: saved, back online → the code', (tester) async {
      final fakes = rider();
      await setSize(tester);
      await pumpApp(tester, fakes);
      await tap(tester, 'Hand over order');
      // No button draws this path yet (Handover 08 has no entry on the frames).
      expect(find.text('Something missing? Check the items'), findsNothing);
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(handoverViewModelProvider.notifier)
          .checkQuantity();
      await settle(tester);
      expect(find.text('Check the items'), findsOneWidget);

      await tester.tap(find.text('−').first);
      await settle(tester);
      expect(find.text('Reset quantities'), findsOneWidget);
      await tap(tester, 'Reset quantities');
      expect(find.text('Reset quantities'), findsNothing);
      // Never more than ordered.
      await tester.tap(find.text('+').first);
      await settle(tester);
      expect(find.text('Reset quantities'), findsNothing);

      await tester.tap(find.text('−').first);
      await settle(tester);
      fakes.signal.online = false;
      await settle(tester);
      await tap(tester, 'Continue to code');
      expect(find.text('Handover saved'), findsOneWidget);

      fakes.signal.online = true;
      await settle(tester);
      expect(find.text('Ask for the customer’s code'), findsOneWidget);
      await type(tester, '4829');
      await tap(tester, 'Confirm delivery');
      expect(fakes.delivery.handovers.single.items.first.quantity, 1);
    });

    testWidgets('Not at gate: offered after a while, the customer is told', (tester) async {
      final fakes = rider();
      await toCode(tester, fakes);
      await tester.pump(HandoverRules.notAtGateAfter);
      await settle(tester);
      expect(find.text('Customer not at the gate?'), findsNothing);
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(handoverViewModelProvider.notifier)
          .notAtGate();
      await settle(tester);
      expect(find.text('Hang on a moment'), findsOneWidget);
      expect(fakes.delivery.customerNotified, 1);

      await tap(tester, 'Can’t reach customer');
      expect(find.text('Report a problem'), findsOneWidget);
      await tap(tester, 'Send report');
      expect(find.text('Report sent'), findsOneWidget);
      expect(fakes.problemReports.sent.single.kind, ProblemKind.customerAbsent);
      await tap(tester, 'Back to order');
      expect(find.text('Hang on a moment'), findsOneWidget);
    });

    testWidgets('Report a problem over the order map', (tester) async {
      final fakes = rider();
      fakes.delivery.order.value = testDeliveryOrder(assignedAt: assigned, status: DeliveryStatus.onTheWay);
      await setSize(tester);
      await pumpApp(tester, fakes);
      // The design draws no button on this map; the report opens from elsewhere.
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(problemReportViewModelProvider.notifier)
          .open();
      await settle(tester);
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.text('Choose what’s happening to continue.'), findsOneWidget);
      await tap(tester, 'Send report');
      expect(fakes.problemReports.sent, isEmpty);

      await tap(tester, 'Unsafe route');
      expect(find.text('Choose what’s happening to continue.'), findsNothing);
      fakes.signal.online = false;
      await settle(tester);
      await tap(tester, 'Send report');
      // Not sent, and the screen is as it was.
      expect(fakes.problemReports.sent, isEmpty);
      expect(find.text('Send report'), findsOneWidget);
      fakes.signal.online = true;
      await settle(tester);
      await tap(tester, 'Send report');
      expect(find.text('Report sent'), findsOneWidget);
      await tap(tester, 'Back to order');
      expect(find.text('Report sent'), findsNothing);
    });
  });
}
