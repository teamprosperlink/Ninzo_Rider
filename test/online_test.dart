import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/core/errors/app_exception.dart';
import 'package:ninzo_rider/core/widgets/rider/rider_ui.dart';
import 'package:ninzo_rider/domain/entities/online_status.dart';
import 'package:ninzo_rider/domain/usecases/online_usecases.dart';
import 'package:ninzo_rider/domain/usecases/spot_usecases.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';
import 'package:ninzo_rider/domain/usecases/shift_flow_usecases.dart';

import 'fakes.dart';

void main() {
  const spot = LatLng(13.1052, 77.5921);
  LatLng away(double meters, [double bearing = 218.66]) => const Distance().offset(spot, meters, bearing);

  group('SpotRules', () {
    test('thresholds', () {
      expect(SpotRules.proximity(1200), SpotProximity.far);
      expect(SpotRules.proximity(301), SpotProximity.far);
      expect(SpotRules.proximity(240), SpotProximity.almostThere);
      expect(SpotRules.proximity(100), SpotProximity.atSpot);
      expect(SpotRules.isAway(150), isFalse);
      expect(SpotRules.isAway(180), isTrue);
      expect(SpotRules.rideMinutes(1200), 5);
      expect(SpotRules.rideMinutes(10), 1);
    });
  });

  group('CheckAtSpot', () {
    late FakeRiderLocation location;
    final shift = testShift();

    setUp(() => location = FakeRiderLocation());

    test('near the spot, or the phone can’t tell: confirmed', () async {
      location.position.value = away(30);
      expect(await CheckAtSpot(location)(shift.spot), isA<SpotConfirmed>());
      location.unavailable = true;
      location.position.value = away(5000);
      expect(await CheckAtSpot(location)(shift.spot), isA<SpotConfirmed>());
    });

    test('clearly elsewhere: too far', () async {
      location.position.value = away(240);
      expect(await CheckAtSpot(location)(shift.spot), isA<SpotTooFar>());
    });
  });

  group('Going online', () {
    late FakeShiftRepository shifts;
    late FakeOnlineRepository online;
    late FakeSignal signal;

    setUp(() {
      shifts = FakeShiftRepository()..shift.value = testShift(phase: ShiftPhase.headingToSpot);
      online = FakeOnlineRepository();
      signal = FakeSignal();
    });

    test('needs signal', () async {
      signal.online = false;
      final result = await GoOnlineAtSpot(online, shifts, signal)('u1', shifts.shift.value!, const OnlineStatus());
      expect(result, GoOnlineAtSpotResult.noSignal);
      expect(shifts.shift.value!.phase, ShiftPhase.headingToSpot);
      expect(online.status.value.onlineAt, isNull);

      final loaded = testShift(phase: ShiftPhase.stockLoaded);
      expect(await GoOnline(shifts, signal)('u1', loaded), GoOnlineResult.noSignal);
    });

    test('starts the Online clock the first time only', () async {
      final go = GoOnlineAtSpot(online, shifts, signal);
      await go('u1', shifts.shift.value!, const OnlineStatus());
      expect(shifts.shift.value!.phase, ShiftPhase.online);
      final first = online.status.value.onlineAt;
      expect(first, isNotNull);

      await ReturnToSpot(shifts)('u1', shifts.shift.value!);
      expect(shifts.shift.value!.phase, ShiftPhase.headingToSpot);
      await go('u1', shifts.shift.value!, online.status.value);
      expect(online.status.value.onlineAt, first);
    });
  });

  group('SelectOnlineAlert', () {
    final shift = testShift(phase: ShiftPhase.online);
    final now = shift.end.subtract(const Duration(hours: 2));
    OnlineAlert? pick(OnlineStatus status, {double? meters, DateTime? timeAdded, DateTime? dismissed, DateTime? at}) =>
        const SelectOnlineAlert()(
          shift: shift,
          status: status,
          now: at ?? now,
          metersFromSpot: meters,
          timeAddedEnd: timeAdded,
          endingDismissedFor: dismissed,
        );

    test('nothing when all is well', () => expect(pick(const OnlineStatus(), meters: 30), isNull));

    test('low stock at 5 items or fewer', () {
      expect(pick(const OnlineStatus(sold: 0)), isNull, reason: '6 left');
      expect((pick(const OnlineStatus(sold: 1)) as LowStockAlert).left, 5);
      expect((pick(const OnlineStatus(sold: 3)) as LowStockAlert).left, 3);
      expect((pick(const OnlineStatus(sold: 9)) as LowStockAlert).left, 0);
    });

    test('battery low at 20% or less', () {
      expect(pick(const OnlineStatus(batteryPercent: 21)), isNull);
      expect((pick(const OnlineStatus(batteryPercent: 15)) as BatteryLowAlert).percent, 15);
    });

    test('shift ending within 15 minutes, until dismissed', () {
      final end = shift.end;
      expect(pick(const OnlineStatus(), at: end.subtract(const Duration(minutes: 16))), isNull);
      final soon = end.subtract(const Duration(minutes: 15));
      expect((pick(const OnlineStatus(), at: soon) as ShiftEndingAlert).minutesLeft, 15);
      expect(pick(const OnlineStatus(), at: soon, dismissed: end), isNull);
      expect(pick(const OnlineStatus(), at: end.add(const Duration(minutes: 1))), isNull, reason: 'already over');
    });

    test('priority: time added, away, ending, battery, low stock', () {
      final soon = shift.end.subtract(const Duration(minutes: 5));
      const all = OnlineStatus(sold: 2, batteryPercent: 10);
      expect(pick(all), isA<BatteryLowAlert>());
      expect(pick(all, at: soon), isA<ShiftEndingAlert>());
      expect(pick(all, at: soon, meters: 180), isA<AwayFromSpotAlert>());
      expect(pick(all, at: soon, meters: 180, timeAdded: shift.end), isA<TimeAddedAlert>());
    });

    test('none while an order is assigned', () {
      const order = AssignedOrder(id: 'a', number: 'A1', gate: 'Gate 1', items: 1);
      expect(pick(const OnlineStatus(sold: 3, queue: [order]), meters: 180), isNull);
    });
  });

  group('Main map', () {
    const order = AssignedOrder(id: 'a', number: 'A1', gate: 'Gate 1', items: 1);

    test('which sheet', () {
      expect(onlineModeOf(const OnlineStatus()), OnlineMode.waiting);
      expect(onlineModeOf(const OnlineStatus(quiet: true)), OnlineMode.quiet);
      expect(onlineModeOf(const OnlineStatus(quiet: true), justConfirmed: true), OnlineMode.spotConfirmed);
      expect(onlineModeOf(const OnlineStatus(), metersFromSpot: 180, justConfirmed: true), OnlineMode.away);
      expect(onlineModeOf(const OnlineStatus(queue: [order]), metersFromSpot: 180), OnlineMode.orderAssigned);
    });

    test('shows 1 order plus up to 4 waiting', () {
      expect(visibleOrders(OnlineStatus(queue: List.filled(7, order))), hasLength(5));
    });

    test('items on scooter: the load, then what’s left when low', () {
      final shift = testShift();
      expect(scooterStockOf(shift, const OnlineStatus()).shown, 4);
      expect(scooterStockOf(shift, const OnlineStatus(sold: 1)).shown, 5);
      expect(scooterStockOf(shift, const OnlineStatus(sold: 9)).shown, 0);
    });

    test('Add time moves the end, from any end already added', () async {
      final online = FakeOnlineRepository();
      final shift = testShift(phase: ShiftPhase.online);
      final add = AddShiftTime(online);
      final first = await add('u1', shift, const OnlineStatus(), AddTimeOption.min30);
      expect(first, shift.end.add(const Duration(minutes: 30)));
      final second = await add('u1', shift, online.status.value, AddTimeOption.hrs4);
      expect(second, first.add(const Duration(hours: 4)));
      await expectLater(add('u1', testShift(), const OnlineStatus(), AddTimeOption.min15), throwsA(isA<AppException>()));
    });

    test('options match the rule', () {
      expect(AddTimeOption.values.map((o) => o.label), ['15 min', '30 min', '45 min', '1 hr', '2 hrs', '3 hrs', '4 hrs']);
    });
  });

  group('Screens', () {
    Fakes rider(ShiftPhase phase, {DateTime? now}) {
      final today = DateTime.now();
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.now = now ?? DateTime(today.year, today.month, today.day, 10);
      fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: phase, scanned: 6);
      return fakes;
    }

    Future<void> tap(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.tap(find.text(text));
      await settle(tester);
    }

    testWidgets('Go online without signal stays on Home', (tester) async {
      final fakes = rider(ShiftPhase.stockLoaded)..signal.online = false;
      await pumpApp(tester, fakes);
      await tap(tester, 'Go online');
      expect(find.byType(SnackBar), findsNothing);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.stockLoaded);
      // The button is usable again: with signal it goes on.
      fakes.signal.online = true;
      await tap(tester, 'Go online');
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.headingToSpot);
    });

    testWidgets('19 → 21 → 22 → 23 → too far → 23 → 24 → 25 → 26', (tester) async {
      final fakes = rider(ShiftPhase.stockLoaded);
      fakes.riderLocation.position.value = away(1200);
      await pumpApp(tester, fakes);
      await tap(tester, 'Go online');
      expect(find.text('Head to Yelahanka Node'), findsOneWidget);

      await tap(tester, 'Navigate to spot');
      expect(find.text('Heading to Yelahanka Node'), findsOneWidget);
      expect(find.text('Turn right (1.2 km)'), findsOneWidget);

      fakes.riderLocation.position.value = away(240);
      await settle(tester);
      expect(find.text('Almost at Yelahanka Node'), findsOneWidget);
      expect(find.text('Turn left (240 m)'), findsOneWidget);

      fakes.riderLocation.position.value = away(30);
      await settle(tester);
      expect(find.text('Are you at Yelahanka Node?'), findsOneWidget);

      // "Not yet": stays on the route, and asks again later.
      await tap(tester, 'Not yet, still on the way');
      expect(find.text('Are you at Yelahanka Node?'), findsNothing);
      await tester.pump(const Duration(seconds: 21));
      await settle(tester);
      expect(find.text('Are you at Yelahanka Node?'), findsOneWidget);

      // Moved off before confirming: the check sends them back (Shift 22).
      fakes.riderLocation.position.value = away(240);
      await settle(tester);
      await tap(tester, 'Yes, I’m at the spot');
      expect(find.text('Checking your location…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('Almost at Yelahanka Node'), findsOneWidget);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.headingToSpot);

      fakes.riderLocation.position.value = away(30);
      await settle(tester);
      await tap(tester, 'Yes, I’m at the spot');
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.online);
      expect(find.text('Online · at spot'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(find.text('Online · at spot'), findsNothing);
      expect(find.text('Online'), findsWidgets);
    });

    testWidgets('Take a break, Go offline, View stock and low stock lead on, and back', (tester) async {
      final fakes = rider(ShiftPhase.online);
      fakes.riderLocation.position.value = away(30);
      fakes.online.status.value = OnlineStatus(onlineAt: fakes.now!.subtract(const Duration(minutes: 12)), sold: 1);
      await pumpApp(tester, fakes);
      expect(find.text('Waiting for orders'), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);

      Future<void> back() async {
        await tester.tap(find.byType(RiderBackButton));
        await settle(tester);
        expect(find.text('Waiting for orders'), findsOneWidget);
      }

      await tap(tester, 'Take a break');
      expect(find.text('How long?'), findsOneWidget);
      await tap(tester, 'Cancel');
      await tap(tester, 'Go offline');
      expect(find.text('End your shift?'), findsOneWidget);
      await tap(tester, 'Stay online');
      expect(find.text('Waiting for orders'), findsOneWidget);
      await tap(tester, 'Request hub to prepare');
      expect(find.text('Refill at Hub 2'), findsOneWidget);
      await back();
      await tap(tester, 'View stock');
      await settle(tester);
      expect(find.text('Your stock'), findsOneWidget);
      expect(find.text('Confirm stock'), findsNothing);
      expect(find.text('Scan next item'), findsNothing);
      await back();
    });

    testWidgets('Add time adds to the shift; Let my shift end dismisses', (tester) async {
      final today = DateTime.now();
      final fakes = rider(ShiftPhase.online, now: DateTime(today.year, today.month, today.day, 18, 15));
      fakes.riderLocation.position.value = away(30);
      final end = DateTime(today.year, today.month, today.day, 18, 30);
      fakes.online.status.value = OnlineStatus(onlineAt: fakes.now, shiftEnd: end);
      await pumpApp(tester, fakes);
      expect(find.text('15 minutes left in your shift'), findsOneWidget);

      await tap(tester, 'Keep riding');
      await tap(tester, 'Let my shift end');
      expect(find.text('15 minutes left in your shift'), findsNothing);
      expect(fakes.online.status.value.shiftEnd, end);

      // The end passes: no action leads to Shift 46.
      fakes.now = end.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 16));
      await settle(tester);
      expect(find.text('Shift limit reached'), findsOneWidget);
    });

    testWidgets('Adding time shows Time added, then goes', (tester) async {
      final today = DateTime.now();
      final fakes = rider(ShiftPhase.online, now: DateTime(today.year, today.month, today.day, 18, 15));
      fakes.riderLocation.position.value = away(30);
      fakes.online.status.value = OnlineStatus(
        onlineAt: fakes.now,
        shiftEnd: DateTime(today.year, today.month, today.day, 18, 30),
      );
      await pumpApp(tester, fakes);
      await tap(tester, 'Keep riding');
      await tap(tester, '1 hr');
      expect(find.text('Keep riding · 1 hr'), findsOneWidget);
      await tap(tester, 'Keep riding · 1 hr');
      expect(find.text('Ends 7:30 PM'), findsOneWidget);
      expect(find.text('Your shift now ends at 7:30 PM. You can add more time later.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
      await settle(tester);
      expect(find.text('Time added'), findsNothing);
    });

    testWidgets('Away → Navigate to spot → Shift 21; order → Start order', (tester) async {
      final fakes = rider(ShiftPhase.online);
      fakes.riderLocation.position.value = away(180);
      fakes.online.status.value = OnlineStatus(onlineAt: fakes.now);
      await pumpApp(tester, fakes);
      expect(find.text('Back to Yelahanka Node?'), findsOneWidget);
      await tap(tester, 'Navigate to spot');
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.headingToSpot);
      expect(find.text('Almost at Yelahanka Node'), findsOneWidget);

      fakes.riderLocation.position.value = away(30);
      await settle(tester);
      await tap(tester, 'Yes, I’m at the spot');
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.online);

      const order = AssignedOrder(id: 'a', number: 'A2931', gate: 'Gate 3', items: 2);
      fakes.online.status.value = fakes.online.status.value.copyWith(queue: const [order]);
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(find.text('Order #A2931 is yours'), findsOneWidget);
      fakes.delivery.order.value = testDeliveryOrder(assignedAt: fakes.now);
      await tap(tester, 'Start order #A2931');
      expect(fakes.online.started, order);
      expect(find.text('Deliver to Gate 3'), findsOneWidget);
    });
  });
}
