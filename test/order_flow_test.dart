import 'package:ninzo_rider/core/constants/demo_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/presentation/orders/viewmodels/order_flow_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninzo_rider/core/errors/app_exception.dart';
import 'package:ninzo_rider/core/utils/formatters.dart';
import 'package:ninzo_rider/domain/entities/app_permission.dart';
import 'package:ninzo_rider/domain/entities/online_status.dart';
import 'package:ninzo_rider/domain/entities/delivery_order.dart';
import 'package:ninzo_rider/domain/usecases/delivery_usecases.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';

import 'fakes.dart';

void main() {
  final assigned = DateTime(2026, 1, 1, 10);

  group('The 90 s clock', () {
    test('runs from the assignment and turns late past 90 s', () {
      final order = testDeliveryOrder(assignedAt: assigned);
      var clock = orderClockOf(order, assigned);
      expect(clock.secondsLeft, 90);
      expect(clock.late, isFalse);
      expect(clock.progress, 1);

      clock = orderClockOf(order, assigned.add(const Duration(seconds: 18)));
      expect(clock.secondsLeft, 72);
      expect(clock.progress, closeTo(0.8, 0.001));

      clock = orderClockOf(order, assigned.add(const Duration(seconds: 90)));
      expect(clock.secondsLeft, 0);
      expect(clock.late, isFalse);

      clock = orderClockOf(order, assigned.add(const Duration(seconds: 91)));
      expect(clock.secondsLeft, 0);
      expect(clock.late, isTrue);
    });
  });

  group('Cancellation pay', () {
    CancellationPay payOf(OrderPayment payment, int amount, int fee) =>
        cancellationPayOf(testDeliveryOrder(payment: payment, amount: amount).copyWith(riderFee: fee));

    test("The trip pay is the order's pay in the earnings, nothing the app works out", () {
      expect(payOf(OrderPayment.upi, 60, 20).kind, CancellationKind.upiFlat);
      expect(payOf(OrderPayment.upi, 60, 20).tripPay, 20);
      expect(payOf(OrderPayment.upi, 60, 35).tripPay, 35);
      expect(payOf(OrderPayment.upi, 60, 0).tripPay, 0);
    });

    test('A pay that is the whole order is Navigate 06; cash is Navigate 05', () {
      expect(payOf(OrderPayment.upi, 16, 16).kind, CancellationKind.upiFull);
      expect(payOf(OrderPayment.cash, 149, 0).kind, CancellationKind.cash);
      expect(payOf(OrderPayment.cash, 149, 0).tripPay, 0);
    });

    test("The demo's backend pays UPI the lesser of ₹20 and the price, cash nothing", () {
      expect(DemoData.cancellationPay(OrderPayment.upi, 60), 20);
      expect(DemoData.cancellationPay(OrderPayment.upi, 20), 20);
      expect(DemoData.cancellationPay(OrderPayment.upi, 16), 16);
      expect(DemoData.cancellationPay(OrderPayment.cash, 149), 0);
    });
  });

  group('Gate proof', () {
    late FakeDeliveryRepository repository;
    late FakeSignal signal;
    late ConfirmGate confirm;
    late DeliveryOrder order;

    setUp(() {
      repository = FakeDeliveryRepository();
      order = testDeliveryOrder(status: DeliveryStatus.onTheWay);
      repository.order.value = order;
      signal = FakeSignal();
      confirm = ConfirmGate(repository, signal);
    });

    test('the right QR code or code confirms', () async {
      expect(await confirm(order, GateMethod.qr, testGateQr), isTrue);
      expect(repository.order.value!.status, DeliveryStatus.atGate);
    });

    test('another gate, or anything that isn\'t a gate code, does not', () async {
      expect(await confirm(order, GateMethod.qr, 'NZG|gate-9'), isFalse);
      expect(await confirm(order, GateMethod.qr, 'NZ1|smash-burger|A-1100|1'), isFalse);
      expect(await confirm(order, GateMethod.code, '12'), isFalse);
      expect(await confirm(order, GateMethod.code, '0000'), isFalse);
      expect(repository.order.value!.status, DeliveryStatus.onTheWay);
    });

    test('the code is trimmed', () async {
      expect(await confirm(order, GateMethod.code, ' $testGateCode '), isTrue);
    });

    test('needs signal', () async {
      signal.online = false;
      await expectLater(confirm(order, GateMethod.qr, testGateQr), throwsA(isA<AppException>()));
    });
  });

  test('An order can only be skipped before setting off', () async {
    final repository = FakeDeliveryRepository()..order.value = testDeliveryOrder();
    final skip = SkipOrder(repository);
    await expectLater(
      skip(testDeliveryOrder(status: DeliveryStatus.onTheWay), SkipReason.notSafe),
      throwsA(isA<AppException>()),
    );
    await skip(testDeliveryOrder(), SkipReason.notSafe);
    expect(repository.order.value!.status, DeliveryStatus.skipped);
    expect(repository.order.value!.skipReason, SkipReason.notSafe);
  });

  test('Distances on the order screens', () {
    expect(kilometres(600), '0.6 km');
    expect(kilometres(100), '0.1 km');
    expect(kilometres(38), '38 m');
  });

  test('No signal outranks what the routing engine reports', () {
    expect(routeIssueOf(signal: true), isNull);
    expect(routeIssueOf(signal: true, reported: RouteIssue.roadClosed), RouteIssue.roadClosed);
    expect(routeIssueOf(signal: false, reported: RouteIssue.roadClosed), RouteIssue.weakSignal);
  });

  test('The location is shared on the way, at most every 10 s', () {
    var now = assigned;
    final repository = FakeDeliveryRepository();
    final share = ShareOrderLocation(repository, () => now);
    const point = LatLng(13, 77);
    share(testDeliveryOrder(), point);
    expect(repository.shared, isEmpty);

    final onTheWay = testDeliveryOrder(status: DeliveryStatus.onTheWay);
    share(onTheWay, point);
    share(onTheWay, point);
    expect(repository.shared, hasLength(1));
    now = now.add(ShareOrderLocation.every);
    share(onTheWay, point);
    expect(repository.shared, hasLength(2));
  });

  group('The flow', () {
    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day, 10);
    LatLng fromGate(double meters, double bearing) => const Distance().offset(testGatePoint, meters, bearing);

    Fakes rider({DeliveryOrder? order, List<AssignedOrder> queue = const []}) {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.now = now;
      fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.online, scanned: 6);
      fakes.permissions.status[AppPermission.camera] = PermissionResult.granted;
      fakes.riderLocation.position.value = fromGate(600, 141.34);
      fakes.delivery.order.value = order ?? testDeliveryOrder(assignedAt: now);
      fakes.online.status.value = OnlineStatus(
        onlineAt: now,
        activeOrderId: 'A2931',
        queue: [const AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', items: 2), ...queue],
      );
      return fakes;
    }

    Future<void> tap(WidgetTester tester, String text) async {
      await tester.tap(find.text(text));
      await settle(tester);
    }

    Future<void> tick(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
    }

    testWidgets('Assigned → Navigate → gate QR → confirmed → handover placeholder', (tester) async {
      final fakes = rider();
      await pumpApp(tester, fakes);
      expect(find.text('New order assigned'), findsOneWidget);
      expect(find.text('1:30'), findsOneWidget);
      expect(find.text('Main entrance · 0.6 km'), findsOneWidget);
      expect(find.text('× 2'), findsOneWidget);
      expect(find.text('In 300 m, turn left'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);

      fakes.now = now.add(const Duration(seconds: 18));
      fakes.riderLocation.position.value = fromGate(300, 138);
      await tap(tester, 'Navigate to Gate 3');
      await tick(tester);
      expect(fakes.delivery.order.value!.status, DeliveryStatus.onTheWay);
      expect(find.text('1:12'), findsOneWidget);
      expect(find.text('0.3 km to the gate'), findsOneWidget);
      expect(find.text('Turn right (0.3 km)'), findsOneWidget);

      await tap(tester, 'I’ve reached the gate');
      expect(fakes.delivery.reachedGate, 1);
      expect(find.text('Confirm you’re at the gate'), findsOneWidget);
      expect(find.text('Point at the gate QR code'), findsOneWidget);

      fakes.riderLocation.position.value = fromGate(38, 138);
      await settle(tester);
      fakes.gateScanner.read('NZG|gate-9');
      await settle(tester);
      expect(find.textContaining('Almost at the gate!'), findsOneWidget);
      expect(find.text('38 m'), findsOneWidget);

      await tap(tester, 'Scan QR again');
      expect(find.text('Point at the gate QR code'), findsOneWidget);

      fakes.gateScanner.read(testGateQr);
      await settle(tester);
      expect(find.text('Gate 3 confirmed'), findsOneWidget);
      expect(find.text('#A2931'), findsOneWidget);

      await tap(tester, 'Hand over order');
      expect(find.text('Pack order #A2931'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Back'));
      await settle(tester);
      expect(find.text('Gate 3 confirmed'), findsOneWidget);
    });

    testWidgets('Skip: reason, keep, submit, back to the map', (tester) async {
      final fakes = rider();
      await pumpApp(tester, fakes);
      await tap(tester, 'Skip this order');
      expect(find.text('Need to skip this order?'), findsOneWidget);
      await tap(tester, 'Keep this order');
      expect(find.text('Deliver to Gate 3'), findsOneWidget);

      await tap(tester, 'Skip this order');
      await tap(tester, 'Not safe to ride');
      await tap(tester, 'Submit');
      expect(find.text('Order skipped'), findsOneWidget);
      expect(find.text('Not safe to ride'), findsOneWidget);
      expect(find.text('Reassigned'), findsOneWidget);

      await tap(tester, 'Back to your spot');
      expect(fakes.online.status.value.activeOrderId, isNull);
      expect(fakes.online.status.value.queue, isEmpty);
    });

    testWidgets('Past 90 s: running late; route issues; a cancellation shows wherever the rider is', (tester) async {
      final fakes = rider(order: testDeliveryOrder(assignedAt: now, status: DeliveryStatus.onTheWay));
      fakes.riderLocation.position.value = fromGate(300, 138);
      await pumpApp(tester, fakes);
      await settle(tester);
      expect(find.text('Call customer (masked)'), findsOneWidget);

      fakes.delivery.issue.value = RouteIssue.roadClosed;
      await settle(tester);
      expect(find.text('Road closed ahead. Finding a new route…'), findsOneWidget);
      expect(find.text('Rerouting…'), findsOneWidget);
      expect(find.text('Turn right (0.3 km)'), findsNothing);

      fakes.delivery.issue.value = RouteIssue.offRoute;
      await settle(tester);
      expect(find.text('You’re off route. Finding a new way…'), findsOneWidget);
      expect(find.text('Finding a new way to Gate 3'), findsOneWidget);

      fakes.delivery.issue.value = null;
      fakes.signal.online = false;
      await settle(tester);
      expect(find.text('Weak signal. Showing your last route.'), findsOneWidget);
      expect(find.text('Onto 2nd Cross · last known route'), findsOneWidget);
      fakes.signal.online = true;
      await settle(tester);

      fakes.now = now.add(const Duration(seconds: 95));
      fakes.riderLocation.position.value = fromGate(100, 156.8);
      await tick(tester);
      expect(find.text('Almost'), findsOneWidget);
      expect(find.text('A few seconds over'), findsOneWidget);
      expect(find.text('Turn left (0.1 km)'), findsOneWidget);
      expect(find.text('Call customer (masked)'), findsNothing);

      await tap(tester, 'I’ve reached the gate');
      // The trip pay is what the earnings paid for the order (order_earnings).
      fakes.delivery.order.value = fakes.delivery.order.value!.copyWith(status: DeliveryStatus.cancelled, riderFee: 20);
      await settle(tester);
      expect(find.text('Order cancelled'), findsOneWidget);
      expect(find.text('Trip pay'), findsOneWidget);
      expect(find.text('₹60'), findsOneWidget);
      expect(find.text('₹20'), findsOneWidget);
    });

    testWidgets('A cash cancellation pays no trip; the next order follows', (tester) async {
      final fakes = rider(
        order: testDeliveryOrder(
          assignedAt: now,
          status: DeliveryStatus.cancelled,
          payment: OrderPayment.cash,
          amount: 149,
        ),
        queue: const [AssignedOrder(id: 'b', number: 'A2934', gate: 'Gate 5', items: 1)],
      );
      fakes.riderLocation.position.value = const Distance().offset(const LatLng(13.1052, 77.5921), 30, 119.4);
      await pumpApp(tester, fakes);
      expect(find.text('Cash on delivery'), findsOneWidget);
      expect(find.text('Trip pay'), findsNothing);

      await tap(tester, 'Back to your spot');
      await settle(tester);
      expect(find.text('Order #A2934 is yours'), findsOneWidget);
    });

    testWidgets('Camera off; turning it on; the gate code', (tester) async {
      final fakes = rider(order: testDeliveryOrder(assignedAt: now, status: DeliveryStatus.onTheWay));
      fakes.permissions.status[AppPermission.camera] = PermissionResult.denied;
      fakes.permissions.denyRequests = true;
      await pumpApp(tester, fakes);
      await tap(tester, 'I’ve reached the gate');
      expect(find.text('Turn on camera to scan'), findsOneWidget);
      expect(find.text('Allow camera access to scan the QR, or enter the gate code instead.'), findsOneWidget);

      fakes.permissions.denyRequests = false;
      await tester.tap(find.text('Turn on camera to scan'), warnIfMissed: false);
      await settle(tester);
      expect(find.text('Point at the gate QR code'), findsOneWidget);

      // The buttons do nothing yet (no design for entering the code).
      final flow = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(orderFlowViewModelProvider.notifier);
      expect(find.text('Enter gate code instead'), findsOneWidget);
      await flow.submitGateCode('0000');
      await settle(tester);
      expect(find.textContaining('Almost at the gate!'), findsOneWidget);

      expect(find.text('Enter gate code'), findsOneWidget);
      await flow.submitGateCode(testGateCode);
      await settle(tester);
      expect(find.text('Gate 3 confirmed'), findsOneWidget);
    });
  });
}
