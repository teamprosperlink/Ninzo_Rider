import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ninzo_rider/features/online/domain/entities/online_status.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift.dart';
import 'package:ninzo_rider/features/shift/presentation/viewmodels/shift_flow_view_model.dart';
import 'package:ninzo_rider/features/shift_end/domain/entities/shift_end.dart';
import 'package:ninzo_rider/features/stock/domain/entities/stock.dart';

import '../../test/fakes.dart';

/// Figma Sections 20–22 (Connection and device issues, End shift, Earnings and
/// sync; 12 frames): drives every state on a device against fake repositories,
/// and saves a screenshot named after each Figma frame, to compare with the
/// design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/connection_endshift_test.dart -d emulator-5554
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

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
    await wait(tester, 100);
  }

  const spot = LatLng(13.1052, 77.5921);
  LatLng from(LatLng point, double meters, double bearing) => const Distance().offset(point, meters, bearing);

  final today = DateTime.now();
  DateTime at(int h, [int m = 0, int s = 0]) => DateTime(today.year, today.month, today.day, h, m, s);

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

  /// Online at the spot in the morning, as the frames have it.
  Fakes rider({OnlineStatus? status, DateTime? now, ShiftPhase phase = ShiftPhase.online}) {
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
    fakes.now = now ?? at(9, 41);
    fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: phase, scanned: 6);
    fakes.riderLocation.position.value = from(spot, 30, 119.4);
    fakes.online.status.value = (status ?? OnlineStatus(onlineAt: fakes.now!.subtract(const Duration(minutes: 12))))
        .copyWith(shiftEnd: () => at(18));
    fakes.stock.load = plainLoad;
    return fakes;
  }

  testWidgets('Shift 40–42: connection and device on the map', (tester) async {
    frameSize(tester);
    final fakes = rider();
    fakes.syncStatus.snapshot = const SyncSnapshot(deliveries: 1);
    fakes.signal.online = false;
    await pumpApp(tester, fakes);
    await wait(tester, 200);
    expect(find.text('No signal'), findsOneWidget);
    expect(find.text('1 delivery waiting to sync'), findsOneWidget);
    expect(find.text('Reconnecting…'), findsOneWidget);
    await shot(tester, 'shift_40_connection_lost');

    fakes.signal.online = true;
    await wait(tester, 200);
    expect(find.text('No signal'), findsNothing);

    fakes.deviceHealth.location = false;
    await tester.pump(const Duration(seconds: 16));
    await settle(tester);
    expect(find.text('Turn on location to keep riding'), findsOneWidget);
    await shot(tester, 'shift_41_location_is_off');

    fakes.deviceHealth.location = true;
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
    expect(find.text('Waiting for orders'), findsOneWidget);

    fakes.deviceHealth.autoTime = false;
    await tester.pump(const Duration(seconds: 16));
    await settle(tester);
    expect(find.text('Let’s fix your phone’s time'), findsOneWidget);
    await shot(tester, 'shift_42_phone_time_is_wrong');

    await tap(tester, 'Check again');
    expect(find.text('Let’s fix your phone’s time'), findsOneWidget);
    fakes.deviceHealth.autoTime = true;
    await tap(tester, 'Check again');
    expect(find.text('Waiting for orders'), findsOneWidget);
  });

  testWidgets('Shift 54, 55: Start riding', (tester) async {
    frameSize(tester);
    final fakes = rider(phase: ShiftPhase.notStarted, now: at(9, 41), status: const OnlineStatus());
    fakes.signal.online = false;
    await pumpApp(tester, fakes);
    expect(find.text('Start riding'), findsOneWidget);
    await tap(tester, 'Start riding');
    await wait(tester, 100);
    expect(find.text('Let’s get you online'), findsOneWidget);
    await shot(tester, 'shift_55_no_internet_at_start');

    fakes.signal.online = true;
    await tap(tester, 'Try again');
    expect(find.text('Start riding'), findsOneWidget);

    fakes.shiftSessions.otherPhone = true;
    await tap(tester, 'Start riding');
    await wait(tester, 100);
    expect(find.text('You’re riding on another phone'), findsOneWidget);
    await shot(tester, 'shift_54_shift_already_open');

    await tap(tester, 'Continue on this phone');
    await wait(tester, 200);
    expect(fakes.shiftSessions.claims, 1);
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.checklist);
  });

  testWidgets('Shift 46–50: end shift', (tester) async {
    frameSize(tester);
    final now = at(9, 41);
    final fakes = rider(
      now: now,
      status: OnlineStatus(onlineAt: at(1, 41), orders: 17, sold: 5),
    );
    fakes.online.status.value = fakes.online.status.value.copyWith(shiftEnd: () => now);
    fakes.shifts.shift.value = fakes.shifts.shift.value!.copyWith(start: at(1, 41), end: now);
    await pumpApp(tester, fakes);
    await tester.pump(const Duration(seconds: 16));
    await settle(tester);
    expect(find.text('Shift limit reached'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('You chose 8 hours. Wrap up, or add more time (up to 4 hours) to keep riding.'), findsOneWidget);
    await shot(tester, 'shift_46_shift_limit_reached');

    await tap(tester, 'End shift');
    fakes.online.status.value = OnlineStatus(onlineAt: at(1, 49), orders: 12, sold: 24, earned: 640, shiftEnd: at(18));
    fakes.shifts.shift.value = fakes.shifts.shift.value!.copyWith(
      stock: const StockLoad(items: 4, portions: 26, scanned: 26),
    );
    await wait(tester, 1100);
    expect(find.text('End your shift?'), findsOneWidget);
    expect(find.text('7h 52m'), findsOneWidget);
    await shot(tester, 'shift_48_end_shift_confirm');

    // An order arrives while the sheet is up.
    final assigned = fakes.now!.subtract(const Duration(seconds: 42));
    final withOrder = fakes.online.status.value.copyWith(
      queue: [
        AssignedOrder(
          id: '4821',
          number: '4821',
          gate: 'Gate 3',
          place: 'Prestige Apts',
          items: 2,
          assignedAt: assigned,
        ),
      ],
    );
    final noOrder = fakes.online.status.value;
    fakes.online.status.value = withOrder;
    await wait(tester, 100);
    await tester.tap(find.text('End shift').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await wait(tester, 1000);
    expect(find.text('Finish your delivery first'), findsOneWidget);
    expect(find.text('Gate 3 · Prestige Apts'), findsOneWidget);
    expect(find.text('0:48'), findsOneWidget);
    await shot(tester, 'shift_47_can_t_end_shift_yet');

    await tap(tester, 'Close');
    expect(find.text('Waiting for orders'), findsNothing);
    fakes.online.status.value = noOrder;
    await wait(tester, 100);

    await tap(tester, 'Go offline');
    final ending = Completer<void>();
    fakes.shifts.phaseGate = ending;
    await tester.tap(find.text('End shift').last);
    await tester.pump();
    await wait(tester, 1000);
    expect(find.text('Ending shift…'), findsOneWidget);
    await shot(tester, 'shift_49_end_shift_ending');

    fakes.online.status.value = fakes.online.status.value.copyWith(averageDeliverySeconds: () => 68);
    ending.complete();
    await wait(tester, 1200);
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.ended);
    expect(find.text('Great shift, Ravi!'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    await shot(tester, 'shift_50_shift_summary');

    await tap(tester, 'Done');
    expect(find.text('You’re offline'), findsOneWidget);
  });

  testWidgets('Earnings 01, Sync 01', (tester) async {
    frameSize(tester);
    final fakes = rider(
      status: OnlineStatus(
        onlineAt: at(9),
        orders: 9,
        earned: 360,
        earnings: const EarningsBreakdown(orderPay: 320, incentives: 30, repositionMinutes: 12, repositionPay: 10),
      ),
    );
    fakes.syncStatus.snapshot = SyncSnapshot(
      deliveries: 1,
      lastSync: at(14, 14),
      events: [
        SyncEvent(label: 'Arrival · Gate 3', at: at(14, 16)),
        SyncEvent(label: 'Handover · #A2931', at: at(14, 17)),
        SyncEvent(label: 'Restock confirmed', at: at(14, 18)),
      ],
    );
    await pumpApp(tester, fakes);
    final flow = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first)).read(shiftFlowViewModelProvider.notifier);

    // No flow-map arrow leads here yet.
    flow.show(ShiftScreen.earnings);
    await settle(tester);
    expect(find.text('₹360'), findsOneWidget);
    await shot(tester, 'earnings_01_today');
    await tap(tester, 'Back to waiting');
    expect(find.text('Waiting for orders'), findsOneWidget);

    fakes.signal.online = false;
    flow.show(ShiftScreen.syncStatus);
    await wait(tester, 200);
    expect(find.text('You’re offline. 3 updates are saved and will send in order once you’re back.'), findsOneWidget);
    await shot(tester, 'sync_01_events_waiting');
    await tap(tester, 'Try again now');
    expect(fakes.syncStatus.retries, 1);
    expect(find.text('Waiting for orders'), findsOneWidget);
  });
}
