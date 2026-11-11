import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ninzo_rider/presentation/orders/viewmodels/handover_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninzo_rider/domain/entities/app_permission.dart';
import 'package:ninzo_rider/domain/entities/online_status.dart';
import 'package:ninzo_rider/domain/entities/delivery_order.dart';
import 'package:ninzo_rider/domain/entities/handover.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';

import '../../test/fakes.dart';

/// Figma Sections 14–15 (Handover, Problem report; 16 frames): drives every
/// state on a device against fake repositories, and saves a screenshot named
/// after each Figma frame, to compare with the design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/handover_test.dart -d emulator-5554
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
    // Let tap ripples fade.
    await tester.pump(const Duration(milliseconds: 700));
    await wait(tester, 800);
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

  Future<void> tapText(WidgetTester tester, String text) => tap(tester, find.text(text).last);

  Future<void> typeCode(WidgetTester tester, String code) async {
    for (final digit in code.split('')) {
      await tap(tester, find.text(digit).last);
    }
  }

  final today = DateTime.now();
  final assignedAt = DateTime(today.year, today.month, today.day, 14, 12, 48);

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

  /// Rider at the gate with Arrival 03 up; "2:14 pm" is when the gate was
  /// confirmed, 1:12 after the assignment.
  Fakes atGate({
    OrderPayment payment = OrderPayment.upi,
    int amount = 60,
    List<AssignedOrder> queue = const [AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', items: 2)],
  }) {
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
    fakes.now = assignedAt.add(const Duration(minutes: 1, seconds: 12));
    fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.online, scanned: 6);
    fakes.permissions.status[AppPermission.camera] = PermissionResult.granted;
    fakes.delivery.order.value = testDeliveryOrder(
      assignedAt: assignedAt,
      status: DeliveryStatus.atGate,
      payment: payment,
      amount: amount,
      gateConfirmedAt: assignedAt.add(const Duration(minutes: 1, seconds: 12)),
    );
    fakes.online.status.value = OnlineStatus(onlineAt: assignedAt, activeOrderId: 'A2931', queue: queue);
    fakes.delivery.onDelivered = (request) {
      final portions = request.items.fold(0, (sum, i) => sum + i.quantity);
      final status = fakes.online.status.value;
      fakes.online.status.value = status.copyWith(
        orders: status.orders + 1,
        earned: status.earned + 40,
        sold: status.sold + portions,
      );
    };
    return fakes;
  }

  Future<void> toPack(WidgetTester tester, Fakes fakes) async {
    await pumpApp(tester, fakes);
    await wait(tester, 100);
    await tapText(tester, 'Hand over order');
    expect(find.text('Pack order #A2931'), findsOneWidget);
  }

  Future<void> tickAll(WidgetTester tester) async {
    await tapText(tester, 'Smash Burger × 2');
    await tapText(tester, 'Paneer Tikka Wrap × 1');
    await tapText(tester, 'Bag sealed');
  }

  testWidgets('Handover 01–06: pack, code, wrong, confirming, delivered', (tester) async {
    frameSize(tester);
    final fakes = atGate();
    await toPack(tester, fakes);
    await tapText(tester, 'Smash Burger × 2');
    await tapText(tester, 'Paneer Tikka Wrap × 1');
    await shot(tester, 'handover_01_pack_order');

    await tapText(tester, 'Bag sealed');
    await tapText(tester, 'Packed – go');
    expect(find.text('Ask for the customer’s code'), findsOneWidget);
    await shot(tester, 'handover_02_enter_code');

    await typeCode(tester, '48');
    await shot(tester, 'handover_03_code_typing');

    await typeCode(tester, '21');
    await tapText(tester, 'Confirm delivery');
    expect(find.textContaining('Almost there!'), findsOneWidget);
    expect(fakes.delivery.handovers, isEmpty);
    await shot(tester, 'handover_04_wrong_code');

    // Typing starts it again.
    await typeCode(tester, '4829');
    final gate = fakes.delivery.handoverGate = Completer<void>();
    await tapText(tester, 'Confirm delivery');
    expect(find.text('Confirming…'), findsOneWidget);
    await shot(tester, 'handover_05_confirming');

    gate.complete();
    await settle(tester);
    expect(find.text('Delivered in 1:12'), findsOneWidget);
    expect(find.text('Nice work. The customer has their order.'), findsOneWidget);
    expect(fakes.online.status.value.sold, 3);
    expect(fakes.delivery.handovers.single.proof, HandoverProof.code);
    await shot(tester, 'handover_06_delivered_no_more_orders');

    await tapText(tester, 'Back to waiting');
    expect(fakes.online.status.value.activeOrderId, isNull);
  });

  testWidgets('Handover 11: next order ready → Order 02', (tester) async {
    frameSize(tester);
    final fakes = atGate(
      queue: const [
        AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', items: 2),
        AssignedOrder(id: 'A2934', number: 'A2934', gate: 'Gate 5', items: 1, collectCash: 149),
      ],
    );
    await toPack(tester, fakes);
    await tickAll(tester);
    await tapText(tester, 'Packed – go');
    await typeCode(tester, '4829');
    await tapText(tester, 'Confirm delivery');
    expect(find.text('Nice work. Your next order is ready to go.'), findsOneWidget);
    expect(find.text('Next · #A2934 · Gate 5'), findsOneWidget);
    await shot(tester, 'handover_11_delivered_next_order_ready');

    await tapText(tester, 'Start next order');
    await wait(tester, 100);
    expect(fakes.online.status.value.activeOrderId, 'A2934');
    expect(fakes.delivery.order.value?.status, DeliveryStatus.onTheWay);
  });

  testWidgets('Handover 07: customer not at the gate', (tester) async {
    frameSize(tester);
    final fakes = atGate();
    await toPack(tester, fakes);
    await tickAll(tester);
    await tapText(tester, 'Packed – go');
    // No button draws this path yet: the frame is reached through the view model.
    await wait(tester, 16000);
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(handoverViewModelProvider.notifier)
        .notAtGate();
    await settle(tester);
    expect(fakes.delivery.customerNotified, 1);
    final since = fakes.now!;
    fakes.now = since.add(const Duration(minutes: 1, seconds: 48));
    await wait(tester, 1100);
    await settle(tester);
    expect(find.text('1:48'), findsOneWidget);
    await shot(tester, 'handover_07_customer_not_at_gate');
  });

  testWidgets('Handover 08, 09, 10: quantity check, partial, saved offline → code', (tester) async {
    frameSize(tester);
    final fakes = atGate();
    await toPack(tester, fakes);
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(handoverViewModelProvider.notifier)
        .checkQuantity();
    await settle(tester);
    expect(find.text('Check the items'), findsOneWidget);
    await shot(tester, 'handover_08_check_quantity');

    await tap(tester, find.text('−').first);
    expect(find.textContaining('You’re handing over 1 of 2 Smash Burgers.'), findsOneWidget);
    await shot(tester, 'handover_09_partial_quantity');

    fakes.signal.online = false;
    await settle(tester);
    await tapText(tester, 'Continue to code');
    await wait(tester, 100);
    expect(find.text('Handover saved'), findsOneWidget);
    expect(find.text('1 event'), findsOneWidget);
    await shot(tester, 'handover_10_saved_offline');

    fakes.signal.online = true;
    await wait(tester, 100);
    expect(find.text('Ask for the customer’s code'), findsOneWidget);
    await typeCode(tester, '4829');
    await tapText(tester, 'Confirm delivery');
    expect(fakes.delivery.handovers.single.items.first.quantity, 1);
    expect(fakes.online.status.value.sold, 2);
  });

  testWidgets('Handover 12: cash has no code', (tester) async {
    frameSize(tester);
    final fakes = atGate(payment: OrderPayment.cash, amount: 149);
    await toPack(tester, fakes);
    await tickAll(tester);
    await tapText(tester, 'Packed – go');
    expect(find.text('Collect ₹149'), findsOneWidget);
    expect(find.text('Ask for the customer’s code'), findsNothing);
    await shot(tester, 'handover_12_collect_cash');

    await tapText(tester, 'I’ve collected ₹149');
    expect(find.text('Delivered in 1:12'), findsOneWidget);
    expect(fakes.delivery.handovers.single.proof, HandoverProof.cash);
  });

  testWidgets('Handover 13: code not working', (tester) async {
    frameSize(tester);
    final fakes = atGate();
    await toPack(tester, fakes);
    await tickAll(tester);
    await tapText(tester, 'Packed – go');
    await typeCode(tester, '1111');
    await tapText(tester, 'Confirm delivery');
    await tapText(tester, 'Code not working? Check order details');
    expect(find.text('Check the order details'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    await shot(tester, 'handover_13_code_not_working_verify_details');

    await tapText(tester, 'Details match, hand over');
    expect(find.text('Delivered in 1:12'), findsOneWidget);
    expect(fakes.delivery.handovers.single.proof, HandoverProof.details);
  });

  testWidgets('Problem 01, 02, 03: report from the code step', (tester) async {
    frameSize(tester);
    final fakes = atGate();
    await toPack(tester, fakes);
    await tickAll(tester);
    await tapText(tester, 'Packed – go');
    await typeCode(tester, '1111');
    await tapText(tester, 'Confirm delivery');
    await tapText(tester, 'Code not working? Check order details');
    await tapText(tester, 'Details don’t match');
    expect(find.text('Report a problem'), findsOneWidget);
    await shot(tester, 'problem_01_whats_happening');

    await tapText(tester, 'Gate closed');
    await shot(tester, 'problem_02_option_chosen');

    await tapText(tester, 'Send report');
    await wait(tester, 100);
    expect(find.text('Report sent'), findsOneWidget);
    await shot(tester, 'problem_03_report_sent');

    await tapText(tester, 'Back to order');
    expect(find.text('Check the order details'), findsOneWidget);
    expect(fakes.problemReports.sent, hasLength(1));
  });
}
