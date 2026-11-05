import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/features/online/domain/entities/online_status.dart';
import 'package:ninzo_rider/features/refill/domain/entities/restock.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift.dart';
import 'package:ninzo_rider/features/stock/domain/entities/stock.dart';

import '../../test/fakes.dart';

/// Figma Sections 16–19 (Refill, Restock, Move to a new spot, Break; 16
/// frames): drives every state on a device against fake repositories, and
/// saves a screenshot named after each Figma frame, to compare with the design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/refill_break_test.dart -d emulator-5554
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
    await wait(tester, 100);
  }

  Future<void> tapText(WidgetTester tester, String text) => tap(tester, find.text(text).last);

  const spot = LatLng(13.1052, 77.5921);
  const jakkur = Spot(name: 'Jakkur Node', point: LatLng(13.1095, 77.5960));
  LatLng from(LatLng point, double meters, double bearing) => const Distance().offset(point, meters, bearing);

  final today = DateTime.now();
  DateTime at(int h, [int m = 0, int s = 0]) => DateTime(today.year, today.month, today.day, h, m, s);

  /// Refill 03's stand-ins ("Image (replace)"): no photos.
  const plainLoad = StockManifest(
    items: [
      StockItem(id: 'smash', name: 'Smash Burger', quantity: 2),
      StockItem(id: 'paneer', name: 'Paneer Tikka Wrap', quantity: 2),
      StockItem(id: 'fries', name: 'Peri Peri Fries', quantity: 1),
      StockItem(id: 'coffee', name: 'Cold Coffee', quantity: 1),
    ],
  );

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

  Fakes rider({OnlineStatus? status, DateTime? now}) {
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
    fakes.now = now ?? at(14);
    fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.online, scanned: 6);
    fakes.riderLocation.position.value = from(spot, 30, 119.4);
    // The sample shift ends at 13:00; the frames say good afternoon, mid-shift.
    fakes.online.status.value = (status ?? OnlineStatus(onlineAt: fakes.now!.subtract(const Duration(minutes: 12))))
        .copyWith(shiftEnd: () => at(18));
    fakes.stock.load = plainLoad;
    return fakes;
  }

  const lines = [
    RestockLine(itemId: 'smash', name: 'Smash Burger', quantity: 4),
    RestockLine(itemId: 'paneer', name: 'Paneer Tikka Wrap', quantity: 0),
  ];

  testWidgets('Refill 01–04', (tester) async {
    frameSize(tester);
    final fakes = rider(
      status: OnlineStatus(
        onlineAt: at(10),
        orders: 9,
        earned: 360,
        sold: 5,
        itemsLeft: const [
          ItemLeft(name: 'Smash Burger', left: 0),
          ItemLeft(name: 'Paneer Tikka Wrap', left: 1),
          ItemLeft(name: 'Peri Peri Fries', left: 0),
        ],
      ),
    );
    await pumpApp(tester, fakes);
    expect(find.text('Only 1 item left'), findsOneWidget);
    await shot(tester, 'refill_01_low_stock');

    fakes.online.status.value = fakes.online.status.value.copyWith(sold: 6);
    await wait(tester, 100);
    expect(find.text('Time to refill'), findsOneWidget);
    await shot(tester, 'refill_02_out_of_stock');

    await tapText(tester, 'Navigate to hub');
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.atHub);
    expect(find.text('Refill at Hub 2'), findsOneWidget);
    await shot(tester, 'refill_03_at_hub');

    await tapText(tester, 'Scan stock');
    await wait(tester, 200);
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.scanning);
    for (final (id, n) in const [('smash', 1), ('smash', 2), ('paneer', 1), ('paneer', 2), ('fries', 1), ('coffee', 1)]) {
      fakes.scanner.read(testCode(id, n));
      await settle(tester);
      await wait(tester, 150);
    }
    await wait(tester, 300);
    expect(find.text('Confirm stock'), findsOneWidget);
    await tapText(tester, 'Confirm stock');
    await wait(tester, 300);
    expect(find.text('Stock refilled'), findsOneWidget);
    await shot(tester, 'refill_04_refilled');

    await tapText(tester, 'Go online');
    await wait(tester, 300);
    expect(fakes.online.status.value.stockAdded, 6);
    expect(fakes.shifts.shift.value!.refill, isNull);
    expect(find.text('Waiting for orders'), findsOneWidget);
  });

  testWidgets('Restock 01–05', (tester) async {
    frameSize(tester);
    final fakes = rider();
    final now = fakes.now!;
    final suggested = RestockRequest(
      stage: RestockStage.suggested,
      hubName: 'Hub 2',
      lines: lines,
      readyInMinutes: 12,
      rideMinutes: 5,
      expiresAt: now.add(const Duration(minutes: 5)),
    );
    fakes.online.status.value = fakes.online.status.value.copyWith(restock: () => suggested);
    await pumpApp(tester, fakes);
    expect(find.text('4 Smash Burgers'), findsOneWidget);
    await shot(tester, 'restock_01_suggested');

    await tapText(tester, 'Edit quantity');
    expect(find.text('Your scooter holds up to 8 items.'), findsOneWidget);
    await shot(tester, 'restock_02_edit_quantity');
    await tapText(tester, 'Cancel');
    expect(find.text('Restock suggestion'), findsOneWidget);

    await tapText(tester, 'Confirm restock');
    final progress = RestockRequest(
      stage: RestockStage.inProgress,
      hubName: 'Hub 2',
      lines: lines,
      queueSlot: 3,
      arriveBy: at(14, 40),
      packing: HubPacking.packing,
      readyAt: now.add(const Duration(minutes: 9)),
    );
    fakes.online.status.value = fakes.online.status.value.copyWith(restock: () => progress);
    await wait(tester, 100);
    expect(find.text('Ready in about 9 min'), findsOneWidget);
    await shot(tester, 'restock_03_hub_progress');

    fakes.online.status.value = fakes.online.status.value.copyWith(
      restock: () => suggested.copyWith(expiresAt: () => now.subtract(const Duration(minutes: 1))),
    );
    await wait(tester, 100);
    expect(find.text('That suggestion ran out'), findsOneWidget);
    await shot(tester, 'restock_04_suggestion_expired');

    fakes.online.status.value = fakes.online.status.value.copyWith(
      restock: () => progress.copyWith(
        stage: RestockStage.hubShort,
        shortage: () => const RestockShortage(
          itemName: 'Smash Burger',
          asked: 4,
          canGive: 2,
          otherHubName: 'Hub 4',
          otherHubKm: 2.1,
          otherHubHas: 4,
        ),
      ),
    );
    await wait(tester, 100);
    expect(find.text('Hub 2 has 2 of 4 Smash Burgers right now.'), findsOneWidget);
    await shot(tester, 'restock_05_hub_is_short');
  });

  testWidgets('Shift 36–39: move to a new spot', (tester) async {
    frameSize(tester);
    final fakes = rider();
    const nudge = RelocationNudge(spot: jakkur, ordersWaiting: 3, meters: 450, rideMinutes: 3);
    fakes.online.status.value = fakes.online.status.value.copyWith(nudge: () => nudge);
    await pumpApp(tester, fakes);
    expect(find.text('Orders waiting at Jakkur Node'), findsOneWidget);
    await shot(tester, 'shift_36_relocation_nudge');

    fakes.online.status.value = fakes.online.status.value.copyWith(nudge: () => nudge.covered);
    await wait(tester, 100);
    expect(find.text('Jakkur Node is covered'), findsOneWidget);
    await shot(tester, 'shift_39_nudge_covered_rare_case');

    fakes.online.status.value = fakes.online.status.value.copyWith(nudge: () => nudge);
    await wait(tester, 100);
    // Down-right of the new spot, as drawn on Shift 37.
    fakes.riderLocation.position.value = from(jakkur.point, 450, 141.34);
    await tapText(tester, 'Navigate to spot');
    await wait(tester, 200);
    expect(find.text('Orders are waiting at Jakkur Node'), findsOneWidget);
    fakes.now = fakes.now!.add(const Duration(minutes: 2, seconds: 14));
    await wait(tester, 1100);
    expect(find.text('02:14'), findsOneWidget);
    await shot(tester, 'shift_37_moving_to_a_new_spot');

    // Down-left, as drawn on Shift 38.
    fakes.riderLocation.position.value = from(jakkur.point, 900, 218.66);
    await tapText(tester, 'Navigate to spot');
    await wait(tester, 200);
    expect(find.text('Heading to Jakkur Node'), findsOneWidget);
    await shot(tester, 'shift_38_moving_to_a_new_spot_on_the_way');
  });

  testWidgets('Shift 43–45: break', (tester) async {
    frameSize(tester);
    final fakes = rider();
    await pumpApp(tester, fakes);
    await tapText(tester, 'Take a break');
    expect(find.text('How long?'), findsOneWidget);
    await shot(tester, 'shift_43_take_a_break');

    await tapText(tester, 'Start break');
    fakes.now = fakes.now!.add(const Duration(seconds: 48));
    await wait(tester, 1100);
    expect(find.text('29:12'), findsOneWidget);
    await shot(tester, 'shift_44_on_a_break');

    fakes.now = fakes.now!.add(const Duration(minutes: 29, seconds: 12 + 130));
    await wait(tester, 1100);
    expect(find.text('+02:10'), findsOneWidget);
    await shot(tester, 'shift_45_break_over');

    await tapText(tester, 'Back online');
    await wait(tester, 200);
    expect(fakes.online.status.value.breakState, isNull);
    expect(find.text('Waiting for orders'), findsOneWidget);
  });
}
