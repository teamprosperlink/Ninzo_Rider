import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/core/utils/time_format.dart';
import 'package:ninzo_rider/core/widgets/rider/rider_ui.dart';
import 'package:ninzo_rider/features/online/domain/entities/online_status.dart';
import 'package:ninzo_rider/features/online/domain/usecases/online_usecases.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/shift/domain/entities/home_status.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift.dart';
import 'package:ninzo_rider/features/shift/domain/usecases/home_status_of.dart';
import 'package:ninzo_rider/features/shift/presentation/viewmodels/shift_flow_view_model.dart';
import 'package:ninzo_rider/features/shift_end/domain/entities/shift_end.dart';
import 'package:ninzo_rider/features/shift_end/domain/usecases/shift_end_usecases.dart';

import 'fakes.dart';

void main() {
  final today = DateTime.now();
  DateTime at(int h, [int m = 0]) => DateTime(today.year, today.month, today.day, h, m);

  const order = AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', items: 2);

  group('Use cases', () {
    test('OpenShift: signal first, then the other phone, unless taking over', () async {
      final signal = FakeSignal();
      final sessions = FakeShiftSessions();
      final open = OpenShift(signal, sessions);
      signal.online = false;
      expect(await open('u1', 's1'), OpenShiftResult.noInternet);
      signal.online = true;
      sessions.otherPhone = true;
      expect(await open('u1', 's1'), OpenShiftResult.alreadyOpen);
      expect(sessions.claims, 0);
      expect(await open('u1', 's1', takeOver: true), OpenShiftResult.opened);
      expect(sessions.claims, 1);
      expect(await open('u1', 's1'), OpenShiftResult.opened);
    });

    test('CheckDeviceHealth: location comes first', () async {
      final health = FakeDeviceHealth();
      final check = CheckDeviceHealth(health);
      expect(await check(), isNull);
      health.autoTime = false;
      expect(await check(), ShiftIssue.phoneTimeWrong);
      health.location = false;
      expect(await check(), ShiftIssue.locationOff);
    });

    test('EndShift: an order comes first; a break ends with the shift', () async {
      final shifts = FakeShiftRepository();
      final online = FakeOnlineRepository();
      final sessions = FakeShiftSessions();
      final end = EndShift(shifts, online, sessions);
      final shift = testShift(phase: ShiftPhase.online);
      shifts.shift.value = shift;

      expect(await end('u1', shift, const OnlineStatus(queue: [order])), EndShiftResult.orderInProgress);
      expect(shifts.shift.value!.phase, ShiftPhase.online);
      expect(sessions.ended, 0);

      online.status.value = OnlineStatus(breakState: BreakState(startedAt: at(9), length: const Duration(minutes: 30)));
      expect(await end('u1', shift, online.status.value), EndShiftResult.ended);
      expect(shifts.shift.value!.phase, ShiftPhase.ended);
      expect(online.status.value.breakState, isNull);
      expect(sessions.ended, 1);
    });

    test('ShiftTotals and the length chosen', () {
      final shift = testShift(phase: ShiftPhase.online, scanned: 6);
      final status = OnlineStatus(onlineAt: at(9), orders: 3, sold: 4, earned: 120, shiftEnd: at(17));
      final totals = ShiftTotals.of(shift, status, at(16, 52));
      expect(totals.left, 2);
      expect(hoursAndMinutes(totals.onlineTime), '7h 52m');
      expect(chosenShiftLength(shift, status), const Duration(hours: 8));
      expect(ShiftTotals.of(shift, const OnlineStatus(), at(16)).onlineTime, Duration.zero);
      expect(chosenShiftLength(shift, const OnlineStatus(chosenLength: Duration(hours: 6))), const Duration(hours: 6));
    });

    test('earningsOf: all order pay until the backend splits it', () {
      expect(earningsOf(const OnlineStatus(earned: 90)).total, 90);
      const split = EarningsBreakdown(orderPay: 320, incentives: 30, repositionMinutes: 12, repositionPay: 10);
      expect(earningsOf(const OnlineStatus(earnings: split)).total, 360);
    });

    test('SelectOnlineAlert: no signal outranks the rest, not an order', () {
      const select = SelectOnlineAlert();
      final shift = testShift(phase: ShiftPhase.online, scanned: 6);
      final status = OnlineStatus(shiftEnd: at(18));
      final alert = select(shift: shift, status: status, now: at(9), offline: true, waitingToSync: 2);
      expect((alert! as ConnectionLostAlert).waiting, 2);
      expect(
        select(shift: shift, status: const OnlineStatus(queue: [order]), now: at(9), offline: true),
        isNull,
      );
    });

    test('Home is Shift 05 once the shift has ended', () {
      expect(
        const HomeStatusOf()(testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.ended), at(10)),
        HomeStatus.startRiding,
      );
    });
  });

  group('Screens', () {
    Fakes rider(ShiftPhase phase, {OnlineStatus? status}) {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
      fakes.now = at(10);
      fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: phase, scanned: 6);
      fakes.riderLocation.position.value = const LatLng(13.1052, 77.5921);
      fakes.online.status.value = (status ?? OnlineStatus(onlineAt: at(9))).copyWith(shiftEnd: () => at(18));
      return fakes;
    }

    Future<void> size(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(2400, 3000)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> tap(WidgetTester tester, String text) async {
      await tester.tap(find.text(text).last);
      await settle(tester);
    }

    testWidgets('Go offline → 48 → 49 → 50 → Done → Home', (tester) async {
      await size(tester);
      final fakes = rider(ShiftPhase.online, status: OnlineStatus(onlineAt: at(9), orders: 2, sold: 3, earned: 80));
      await pumpApp(tester, fakes);
      await tap(tester, 'Go offline');
      expect(find.text('End your shift?'), findsOneWidget);
      expect(find.text('1h 00m'), findsOneWidget);
      await tap(tester, 'Stay online');
      expect(find.text('Waiting for orders'), findsOneWidget);

      await tap(tester, 'Go offline');
      await tap(tester, 'End shift');
      expect(find.text('Ending shift…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.ended);
      expect(fakes.shiftSessions.ended, 1);
      expect(find.text('Great shift, Ravi!'), findsOneWidget);
      expect(find.text('₹80'), findsOneWidget);
      expect(find.text('3 items'), findsNWidgets(2));

      await tap(tester, 'Done');
      expect(find.text('You’re offline'), findsOneWidget);
      expect(find.text('Start riding'), findsOneWidget);
    });

    testWidgets('End shift from a break ends the break too', (tester) async {
      await size(tester);
      final fakes = rider(
        ShiftPhase.online,
        status: OnlineStatus(onlineAt: at(9), breakState: BreakState(startedAt: at(10), length: const Duration(minutes: 30))),
      );
      await pumpApp(tester, fakes);
      expect(find.text('Enjoy your break'), findsOneWidget);
      await tap(tester, 'End shift');
      expect(find.text('End your shift?'), findsOneWidget);
      await tap(tester, 'Stay online');
      expect(find.text('Enjoy your break'), findsOneWidget);

      await tap(tester, 'End shift');
      await tap(tester, 'End shift');
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(fakes.online.status.value.breakState, isNull);
      expect(find.text('Here’s how today went.'), findsOneWidget);
    });

    testWidgets('An order while confirming: 47; Close → the map', (tester) async {
      await size(tester);
      final fakes = rider(ShiftPhase.online);
      await pumpApp(tester, fakes);
      await tap(tester, 'Go offline');
      fakes.online.status.value = fakes.online.status.value.copyWith(
        queue: [AssignedOrder(id: 'A2931', number: 'A2931', gate: 'Gate 3', place: 'Prestige Apts', items: 2, assignedAt: at(10))],
      );
      await settle(tester);
      await tap(tester, 'End shift');
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('Finish your delivery first'), findsOneWidget);
      expect(find.text('Gate 3 · Prestige Apts'), findsOneWidget);
      expect(find.text('1:30'), findsOneWidget);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.online);
      await tap(tester, 'Close');
      expect(find.text('Order #A2931 is yours'), findsOneWidget);
    });

    testWidgets('The shift\'s end: 46; Keep riding → the map, End shift → 48', (tester) async {
      await size(tester);
      final fakes = rider(ShiftPhase.online);
      fakes.online.status.value = fakes.online.status.value.copyWith(shiftEnd: () => at(10));
      fakes.shifts.shift.value = fakes.shifts.shift.value!.copyWith(start: at(2));
      await pumpApp(tester, fakes);
      await tester.pump(const Duration(seconds: 16));
      await settle(tester);
      expect(find.text('Shift limit reached'), findsOneWidget);
      expect(find.textContaining('You chose 8 hours.'), findsOneWidget);
      await tap(tester, 'Keep riding');
      expect(find.text('Waiting for orders'), findsOneWidget);
      // Doesn't ask again for the same end.
      await tester.pump(const Duration(seconds: 16));
      await settle(tester);
      expect(find.text('Shift limit reached'), findsNothing);
    });

    testWidgets('No signal on the map: Shift 40 comes and goes', (tester) async {
      await size(tester);
      final fakes = rider(ShiftPhase.online);
      fakes.syncStatus.snapshot = const SyncSnapshot(deliveries: 1);
      await pumpApp(tester, fakes);
      expect(find.text('No signal'), findsNothing);
      fakes.signal.online = false;
      await settle(tester);
      expect(find.text('No signal'), findsOneWidget);
      expect(find.text('Reconnecting…'), findsOneWidget);
      expect(find.text('1 delivery waiting to sync'), findsOneWidget);
      fakes.signal.online = true;
      await settle(tester);
      expect(find.text('No signal'), findsNothing);
      // The pill, and the stat.
      expect(find.text('Online'), findsNWidgets(2));
    });

    testWidgets('Location off: 41; Open settings; back when on; Go offline → 48', (tester) async {
      await size(tester);
      final fakes = rider(ShiftPhase.online);
      fakes.deviceHealth.location = false;
      await pumpApp(tester, fakes);
      expect(find.text('Turn on location to keep riding'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      await tap(tester, 'Open settings');
      expect(fakes.deviceHealth.locationOpened, 1);
      expect(find.text('Turn on location to keep riding'), findsOneWidget);
      await tap(tester, 'Go offline');
      expect(find.text('End your shift?'), findsOneWidget);
      await tap(tester, 'Stay online');
      fakes.deviceHealth.location = true;
      await tester.pump(const Duration(seconds: 16));
      await settle(tester);
      expect(find.text('Waiting for orders'), findsOneWidget);

      fakes.deviceHealth.location = false;
      await tester.pump(const Duration(seconds: 16));
      await settle(tester);
      fakes.deviceHealth.location = true;
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(find.text('Waiting for orders'), findsOneWidget);
    });

    testWidgets('Phone time wrong: 42; Check again only leaves once it\'s right', (tester) async {
      await size(tester);
      final fakes = rider(ShiftPhase.online);
      fakes.deviceHealth.autoTime = false;
      await pumpApp(tester, fakes);
      expect(find.text('Let’s fix your phone’s time'), findsOneWidget);
      await tap(tester, 'Open date settings');
      expect(fakes.deviceHealth.dateOpened, 1);
      await tap(tester, 'Check again');
      expect(find.text('Let’s fix your phone’s time'), findsOneWidget);
      fakes.deviceHealth.autoTime = true;
      await tap(tester, 'Check again');
      expect(find.text('Waiting for orders'), findsOneWidget);
    });

    testWidgets('Start riding: 55, Try again → Home; 54, Cancel, Continue → checklist', (tester) async {
      await size(tester);
      final fakes = rider(ShiftPhase.notStarted, status: const OnlineStatus());
      fakes.signal.online = false;
      await pumpApp(tester, fakes);
      await tap(tester, 'Start riding');
      expect(find.text('Let’s get you online'), findsOneWidget);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.notStarted);
      fakes.signal.online = true;
      await tap(tester, 'Try again');
      expect(find.text('Start riding'), findsOneWidget);

      fakes.shiftSessions.otherPhone = true;
      await tap(tester, 'Start riding');
      expect(find.text('You’re riding on another phone'), findsOneWidget);
      await tap(tester, 'Cancel');
      expect(find.text('Start riding'), findsOneWidget);
      expect(fakes.shiftSessions.claims, 0);

      await tap(tester, 'Start riding');
      await tap(tester, 'Continue on this phone');
      expect(fakes.shiftSessions.claims, 1);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.checklist);
    });

    testWidgets('Earnings 01 and Sync 01 lead back to the map', (tester) async {
      await size(tester);
      final fakes = rider(
        ShiftPhase.online,
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
        events: [SyncEvent(label: 'Handover · #A2931', at: at(14, 17))],
      );
      await pumpApp(tester, fakes);
      final flow = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      ).read(shiftFlowViewModelProvider.notifier);

      flow.show(ShiftScreen.earnings);
      await settle(tester);
      expect(find.text('₹360'), findsOneWidget);
      expect(find.text('Repositioning (12 min)'), findsOneWidget);
      await tap(tester, 'Back to waiting');
      expect(find.text('Waiting for orders'), findsOneWidget);

      flow.show(ShiftScreen.earnings);
      await settle(tester);
      await tester.tap(find.byType(RiderBackButton));
      await settle(tester);
      expect(find.text('Waiting for orders'), findsOneWidget);

      fakes.signal.online = false;
      await settle(tester);
      flow.show(ShiftScreen.syncStatus);
      await settle(tester);
      expect(find.text('You’re offline. 1 update is saved and will send in order once you’re back.'), findsOneWidget);
      expect(find.text('2:14 pm'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      fakes.signal.online = true;
      await settle(tester);
      expect(find.textContaining('You’re offline.'), findsNothing);
      await tap(tester, 'Try again now');
      expect(fakes.syncStatus.retries, 1);
      expect(find.text('Waiting for orders'), findsOneWidget);
    });
  });
}
