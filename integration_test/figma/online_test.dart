import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/domain/entities/online_status.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';

import '../../test/fakes.dart';

/// Figma Sections 9–10 (Go online at spot, Online states and alerts; 17
/// frames): drives every state on a device against fake repositories, and
/// saves a screenshot named after each Figma frame, to compare with the
/// design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/online_test.dart -d emulator-5554
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

  const spot = LatLng(13.1052, 77.5921);
  LatLng from(double meters, double bearing) => const Distance().offset(spot, meters, bearing);

  final today = DateTime.now();
  DateTime at(int h, [int m = 0]) => DateTime(today.year, today.month, today.day, h, m);

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

  Fakes rider({required ShiftPhase phase}) {
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
    fakes.now = at(10);
    fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: phase, scanned: 6);
    return fakes;
  }

  testWidgets('Go online at spot matches Figma', (tester) async {
    frameSize(tester);
    final fakes = rider(phase: ShiftPhase.stockLoaded);
    // Down-right of the spot, as drawn on Shift 19.
    fakes.riderLocation.position.value = from(1200, 141.34);
    await pumpApp(tester, fakes);

    await tap(tester, find.text('Go online'));
    await wait(tester, 100);
    expect(find.text('Head to Yelahanka Node'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    await shot(tester, 'shift_19_go_online_at_spot');

    await tap(tester, find.text('Items on scooter'));
    await wait(tester, 100);
    expect(find.text('Paneer Tikka Wrap'), findsOneWidget);
    await shot(tester, 'shift_20_items_list_open');
    await tap(tester, find.text('Items on scooter'));

    // Down-left, as drawn on Shift 21.
    fakes.riderLocation.position.value = from(1200, 218.66);
    await tap(tester, find.text('Navigate to spot'));
    await wait(tester, 100);
    expect(find.text('Heading to Yelahanka Node'), findsOneWidget);
    await shot(tester, 'shift_21_heading_to_spot');

    fakes.riderLocation.position.value = from(240, 218.66);
    await wait(tester, 100);
    expect(find.text('Almost at Yelahanka Node'), findsOneWidget);
    await shot(tester, 'shift_22_too_far_from_spot');

    // Reached it: just right of the spot, as drawn on Shift 23.
    fakes.riderLocation.position.value = from(30, 119.4);
    await wait(tester, 100);
    expect(find.text('Are you at Yelahanka Node?'), findsOneWidget);
    await shot(tester, 'shift_23_confirm_you_re_at_the_spot');

    final check = Completer<void>();
    fakes.riderLocation.gate = check;
    await tap(tester, find.text('Yes, I’m at the spot'));
    expect(find.text('Checking your location…'), findsOneWidget);
    await shot(tester, 'shift_24_confirm_at_spot_checking_location');

    fakes.online.status.value = OnlineStatus(onlineAt: at(9, 48));
    check.complete();
    for (var i = 0; i < 30 && fakes.shifts.shift.value!.phase != ShiftPhase.online; i++) {
      await wait(tester, 100);
    }
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.online);
    expect(find.text('Online · at spot'), findsOneWidget);
    await shot(tester, 'shift_25_spot_confirmed_by_rider');

    await wait(tester, 4000);
    expect(find.text('Online · at spot'), findsNothing);
    expect(find.text('Stay at Yelahanka Node. Orders near you are assigned automatically.'), findsOneWidget);
    await shot(tester, 'shift_26_online_waiting');
  });

  testWidgets('Online states and alerts match Figma', (tester) async {
    frameSize(tester);
    final fakes = rider(phase: ShiftPhase.online);
    fakes.riderLocation.position.value = from(30, 119.4);
    final waiting = OnlineStatus(onlineAt: at(9, 48));
    fakes.online.status.value = waiting;
    await pumpApp(tester, fakes);
    await wait(tester, 100);

    fakes.online.status.value = OnlineStatus(onlineAt: at(9, 18), quiet: true);
    await wait(tester, 100);
    expect(find.text('It’s quiet right now'), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);
    await shot(tester, 'shift_27_online_quiet_spell');

    fakes.online.status.value = waiting.copyWith(
      queue: const [
        AssignedOrder(id: 'a', number: 'A2931', gate: 'Gate 3', items: 2),
        AssignedOrder(id: 'b', number: 'A2934', gate: 'Gate 5', items: 1, collectCash: 149),
        AssignedOrder(id: 'c', number: 'A2936', gate: 'Gate 1', items: 3),
        AssignedOrder(id: 'd', number: 'A2938', gate: 'Gate 7', items: 2),
        AssignedOrder(id: 'e', number: 'A2940', gate: 'Gate 2', items: 1, collectCash: 99),
      ],
    );
    await wait(tester, 100);
    expect(find.text('Order #A2931 is yours'), findsOneWidget);
    await shot(tester, 'shift_28_online_order_assigned');

    fakes.online.status.value = waiting.copyWith(sold: 1);
    await wait(tester, 100);
    expect(find.text('Only 5 items left'), findsOneWidget);
    expect(find.text('5 items on scooter'), findsOneWidget);
    await shot(tester, 'shift_29_online_low_stock_5_left');

    fakes.online.status.value = waiting;
    fakes.riderLocation.position.value = from(180, 119.4);
    await wait(tester, 100);
    expect(find.text('Back to Yelahanka Node?'), findsOneWidget);
    expect(find.textContaining('180 m away right now'), findsOneWidget);
    await shot(tester, 'shift_30_online_away_from_spot');

    fakes.riderLocation.position.value = from(30, 119.4);
    fakes.online.status.value = waiting.copyWith(batteryPercent: () => 15);
    await wait(tester, 100);
    expect(find.text('Scooter battery is at 15%'), findsOneWidget);
    await shot(tester, 'shift_31_online_scooter_battery_low');

    // Shift ending: 15 minutes before 6:30 PM.
    fakes.now = at(18, 15);
    final ending = OnlineStatus(onlineAt: at(18, 3), shiftEnd: at(18, 30));
    fakes.online.status.value = ending;
    await wait(tester, 100);
    expect(find.text('15 minutes left in your shift'), findsOneWidget);
    await shot(tester, 'shift_32_online_shift_ending_soon');

    await tap(tester, find.text('Keep riding'));
    expect(find.text('Want to keep riding?'), findsOneWidget);
    await shot(tester, 'shift_33_add_time');

    final adding = Completer<void>();
    fakes.online.gate = adding;
    await tap(tester, find.text('Keep riding · 30 min'));
    expect(find.text('Adding time…'), findsOneWidget);
    await shot(tester, 'shift_34_add_time_adding');

    adding.complete();
    await wait(tester, 200);
    expect(find.text('Time added'), findsOneWidget);
    expect(find.text('Ends 7:00 PM'), findsOneWidget);
    await shot(tester, 'shift_35_online_time_added');
  });
}
