import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/domain/entities/app_permission.dart';
import 'package:ninzo_rider/domain/entities/online_status.dart';
import 'package:ninzo_rider/domain/entities/delivery_order.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';

import '../../test/fakes.dart';

/// Figma Sections 11–13 (Order, Gate arrival, Navigate and cancels; 15 frames):
/// drives every state on a device against fake repositories, and saves a
/// screenshot named after each Figma frame, to compare with the design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/order_test.dart -d emulator-5554
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceReady = false;

  Future<void> wait(WidgetTester tester, int ms) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    // Let tap ripples fade and map tiles load.
    await tester.pump(const Duration(milliseconds: 700));
    await wait(tester, 1500);
    if (Platform.isAndroid && !surfaceReady) {
      await binding.convertFlutterSurfaceToImage();
      surfaceReady = true;
      await tester.pump();
    }
    await binding.takeScreenshot(name);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  final today = DateTime.now();
  final assignedAt = DateTime(today.year, today.month, today.day, 10);
  const gate = LatLng(13.1100, 77.5900);
  LatLng fromGate(double meters, double bearing) => const Distance().offset(gate, meters, bearing);

  // Where the design draws the rider.
  final legAssigned = fromGate(600, 141.34), legOnTheWay = fromGate(300, 138.01), legLate = fromGate(100, 156.8);

  void frameSize(WidgetTester tester) {
    surfaceReady = false;
    // Lay out at the Figma frame size, 360 × 800 with a 48px status bar.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 144, bottom: 48)
      ..viewPadding = const FakeViewPadding(top: 144, bottom: 48);
    addTearDown(tester.view.reset);
  }

  Fakes rider(DeliveryOrder order) {
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
    fakes.now = assignedAt;
    fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.online, scanned: 6);
    fakes.permissions.status[AppPermission.camera] = PermissionResult.granted;
    fakes.delivery.order.value = order;
    fakes.online.status.value = OnlineStatus(
      onlineAt: assignedAt,
      activeOrderId: order.id,
      queue: const [AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', items: 2)],
    );
    return fakes;
  }

  DeliveryOrder order({
    DeliveryStatus status = DeliveryStatus.assigned,
    OrderPayment payment = OrderPayment.upi,
    int amount = 60,
  }) => testDeliveryOrder(assignedAt: assignedAt, status: status, payment: payment, amount: amount, gatePoint: gate);

  testWidgets('Order 01, 04, 05: assigned, skipping', (tester) async {
    frameSize(tester);
    final fakes = rider(order());
    fakes.riderLocation.position.value = legAssigned;
    await pumpApp(tester, fakes);
    await wait(tester, 100);
    expect(find.text('1:30'), findsOneWidget);
    expect(find.text('New order assigned'), findsOneWidget);
    expect(find.text('Main entrance · 0.6 km'), findsOneWidget);
    expect(find.text('0.6 km'), findsOneWidget);
    await shot(tester, 'order_01_order_assigned');

    await tap(tester, find.text('Skip this order'));
    expect(find.text('Need to skip this order?'), findsOneWidget);
    await shot(tester, 'order_04_can_t_take_order');

    await tap(tester, find.text('Submit'));
    expect(find.text('Order skipped'), findsOneWidget);
    await shot(tester, 'order_05_order_skipped');
  });

  testWidgets('Order 02, 03, Navigate 01–03: on the way', (tester) async {
    frameSize(tester);
    final fakes = rider(order(status: DeliveryStatus.onTheWay));
    fakes.riderLocation.position.value = legOnTheWay;
    fakes.now = assignedAt.add(const Duration(seconds: 18));
    await pumpApp(tester, fakes);
    await wait(tester, 100);
    expect(find.text('1:12'), findsOneWidget);
    expect(find.text('Turn right (0.3 km)'), findsOneWidget);
    await shot(tester, 'order_02_on_the_way');

    fakes.signal.online = false;
    await wait(tester, 100);
    expect(find.text('Weak signal. Showing your last route.'), findsOneWidget);
    await shot(tester, 'navigate_01_weak_signal');

    fakes.signal.online = true;
    fakes.delivery.issue.value = RouteIssue.roadClosed;
    await wait(tester, 100);
    expect(find.text('Road closed ahead. Finding a new route…'), findsOneWidget);
    await shot(tester, 'navigate_02_road_closed');

    fakes.delivery.issue.value = RouteIssue.offRoute;
    await wait(tester, 100);
    expect(find.text('You’re off route. Finding a new way…'), findsOneWidget);
    await shot(tester, 'navigate_03_off_route');

    fakes.delivery.issue.value = null;
    fakes.riderLocation.position.value = legLate;
    fakes.now = assignedAt.add(const Duration(seconds: 95));
    await wait(tester, 1100);
    expect(find.text('Almost'), findsOneWidget);
    expect(find.text('Turn left (0.1 km)'), findsOneWidget);
    await shot(tester, 'order_03_running_late');
  });

  testWidgets('Arrival 01–04: at the gate', (tester) async {
    frameSize(tester);
    final fakes = rider(order(status: DeliveryStatus.onTheWay));
    fakes.riderLocation.position.value = legLate;
    fakes.now = assignedAt.add(const Duration(seconds: 40));
    await pumpApp(tester, fakes);
    await wait(tester, 100);
    await tap(tester, find.text('I’ve reached the gate'));
    await wait(tester, 100);
    expect(find.text('Point at the gate QR code'), findsOneWidget);
    await shot(tester, 'arrival_01_scan_gate_qr');

    fakes.riderLocation.position.value = fromGate(38, 138);
    await wait(tester, 100);
    fakes.gateScanner.read('NZG|gate-9');
    await wait(tester, 100);
    expect(find.text('38 m'), findsOneWidget);
    await shot(tester, 'arrival_02_not_confirmed');

    await tap(tester, find.text('Scan QR again'));
    fakes.gateScanner.fail();
    await wait(tester, 100);
    expect(find.text('Turn on camera to scan'), findsOneWidget);
    await shot(tester, 'arrival_04_camera_off');

    await tester.tap(find.text('Turn on camera to scan'), warnIfMissed: false);
    await wait(tester, 100);
    fakes.riderLocation.position.value = fromGate(12, 138);
    await wait(tester, 100);
    fakes.gateScanner.read(testGateQr);
    await wait(tester, 100);
    expect(find.text('Gate 3 confirmed'), findsOneWidget);
    expect(find.text('12 m'), findsOneWidget);
    await shot(tester, 'arrival_03_gate_confirmed');
  });

  testWidgets('Navigate 04–06: cancellations', (tester) async {
    frameSize(tester);
    final fakes = rider(order(status: DeliveryStatus.cancelled));
    fakes.riderLocation.position.value = legOnTheWay;
    await pumpApp(tester, fakes);
    await wait(tester, 100);
    expect(find.text('₹60'), findsOneWidget);
    expect(find.text('₹20'), findsOneWidget);
    await shot(tester, 'navigate_04_order_cancelled_upi_20_or_more');

    fakes.delivery.order.value = order(status: DeliveryStatus.cancelled, payment: OrderPayment.cash, amount: 149);
    await wait(tester, 100);
    expect(find.text('Cash on delivery'), findsOneWidget);
    await shot(tester, 'navigate_05_order_cancelled_cash');

    fakes.delivery.order.value = order(status: DeliveryStatus.cancelled, amount: 16);
    await wait(tester, 100);
    expect(find.text('₹16'), findsNWidgets(2));
    await shot(tester, 'navigate_06_order_cancelled_upi_under_20');
  });
}
