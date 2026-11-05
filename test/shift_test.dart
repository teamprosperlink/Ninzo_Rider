import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ninzo_rider/core/error/app_exception.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/shift/domain/entities/home_status.dart';
import 'package:ninzo_rider/features/shift/domain/entities/pre_shift_check.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift_push.dart';
import 'package:ninzo_rider/features/shift/domain/usecases/home_status_of.dart';
import 'package:ninzo_rider/features/shift/domain/usecases/plan_shift_pushes.dart';
import 'package:ninzo_rider/features/shift/domain/usecases/shift_flow_usecases.dart';
import 'package:ninzo_rider/features/shift/domain/usecases/stock_request_usecases.dart';

import 'fakes.dart';

void main() {
  final today = DateTime.now();
  DateTime at(int h, [int m = 0]) => DateTime(today.year, today.month, today.day, h, m);

  group('HomeStatusOf', () {
    const of = HomeStatusOf();
    HomeStatus status(StockRequestStatus s, {ShiftPhase phase = ShiftPhase.notStarted, int hour = 8}) =>
        of(testShift(stockRequest: s, phase: phase), at(hour));

    test('follows the stock request before the shift', () {
      expect(status(StockRequestStatus.notRequested), HomeStatus.stockNotRequested);
      expect(status(StockRequestStatus.awaitingReply), HomeStatus.stockNotRequested);
      expect(status(StockRequestStatus.notWorkingToday), HomeStatus.offToday);
      expect(status(StockRequestStatus.requested), HomeStatus.hubPreparing);
      expect(status(StockRequestStatus.packing), HomeStatus.hubPreparing);
      expect(status(StockRequestStatus.ready), HomeStatus.stockReady);
    });

    test('Start riding once the shift has begun, packed or still packing', () {
      expect(status(StockRequestStatus.ready, hour: 9), HomeStatus.startRiding);
      expect(status(StockRequestStatus.packing, hour: 10), HomeStatus.startRiding);
      expect(status(StockRequestStatus.notRequested, hour: 10), HomeStatus.stockNotRequested);
    });

    test('follows the phase after Start riding', () {
      const ready = StockRequestStatus.ready;
      expect(status(ready, phase: ShiftPhase.headingToHub), HomeStatus.collectStock);
      expect(status(ready, phase: ShiftPhase.atHub), HomeStatus.collectStock);
      expect(status(ready, phase: ShiftPhase.scanning), HomeStatus.finishScanning);
      expect(status(ready, phase: ShiftPhase.stockLoaded), HomeStatus.stockLoaded);
      expect(of(testShift(), at(8), starting: true), HomeStatus.starting);
    });
  });

  group('PlanShiftPushes', () {
    const plan = PlanShiftPushes(ShiftPushTimes());

    test('asks 1 h before and reminds at 30 min while there is no reply', () {
      final p = plan(testShift(), at(7));
      expect(p.schedule, {ShiftPush.prepareStock: at(8), ShiftPush.reminder: at(8, 30)});
    });

    test('a push long past is dropped; a reply cancels both', () {
      expect(plan(testShift(), at(8, 20)).schedule.keys, [ShiftPush.reminder]);
      final replied = plan(testShift(stockRequest: StockRequestStatus.requested), at(8, 5));
      expect(replied.schedule, isEmpty);
      expect(replied.cancel, {ShiftPush.prepareStock, ShiftPush.reminder});
    });

    test('"Stock ready" when the hub finishes packing', () {
      final packed = plan(
        testShift(stockRequest: StockRequestStatus.ready),
        at(8, 40),
        previous: testShift(stockRequest: StockRequestStatus.packing),
      );
      expect(packed.showNow, {ShiftPush.stockReady});
      expect(plan(testShift(stockRequest: StockRequestStatus.ready), at(8, 41)).showNow, isEmpty);
    });

    test('push text matches the design', () {
      final c = ShiftPushContent.of(ShiftPush.prepareStock, testShift());
      expect(c.title, 'Shift starts at 9:00 AM');
      expect(c.actions.values, ['I’m coming', 'Not today']);
      expect(ShiftPushContent.of(ShiftPush.stockReady, testShift()).title, 'Your stock is ready at Hub 2');
    });
  });

  group('Shift use cases', () {
    late FakeShiftRepository repo;
    setUp(() => repo = FakeShiftRepository());

    test('replying: yes packs, no means not today, asking twice changes nothing', () async {
      final reply = ReplyToStockRequest(repo);
      await reply('u1', testShift(), coming: false);
      expect(repo.shift.value!.stockRequest, StockRequestStatus.notWorkingToday);
      await reply('u1', repo.shift.value!, coming: true);
      expect(repo.shift.value!.stockRequest, StockRequestStatus.requested);
      await reply('u1', repo.shift.value!, coming: true);
      expect(repo.shift.value!.stockRequest, StockRequestStatus.requested);
      expect(() => reply('u1', repo.shift.value!, coming: false), throwsA(isA<AppException>()));
    });

    test('Start riding needs a confirmed request, and packed stock or the shift begun', () async {
      expect(() => StartShift(repo, () => at(10))('u1', testShift()), throwsA(isA<AppException>()));
      final packing = testShift(stockRequest: StockRequestStatus.packing);
      expect(() => StartShift(repo, () => at(8))('u1', packing), throwsA(isA<AppException>()));
      await StartShift(repo, () => at(9, 5))('u1', packing);
      expect(repo.shift.value!.phase, ShiftPhase.checklist);
    });

    test('Go to hub needs every check; Go online needs loaded stock', () async {
      final shift = testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.checklist);
      expect(() => FinishChecklist(repo)('u1', shift, {PreShiftCheck.helmet}), throwsA(isA<AppException>()));
      await FinishChecklist(repo)('u1', shift, PreShiftCheck.values.toSet());
      expect(repo.shift.value!.phase, ShiftPhase.headingToHub);

      expect(await GoOnline(repo, FakeSignal())('u1', repo.shift.value!), GoOnlineResult.needsStock);
      await RecordStockScans(repo)('u1', repo.shift.value!, 6, confirm: true);
      expect(repo.shift.value!.phase, ShiftPhase.stockLoaded);
      expect(await GoOnline(repo, FakeSignal())('u1', repo.shift.value!), GoOnlineResult.headToSpot);
      expect(repo.shift.value!.phase, ShiftPhase.headingToSpot);
    });

    test('device checks: phone battery, location, scooter charge', () async {
      final device = FakeDeviceStatus()..battery = 30;
      final check = CheckPreShiftItem(device);
      expect(await check(PreShiftCheck.helmet, testShift()), isNull);
      expect(await check(PreShiftCheck.phoneCharged, testShift()), CheckProblem.phoneBatteryLow);
      device.location = false;
      expect(await check(PreShiftCheck.location, testShift()), CheckProblem.locationOff);
      expect(await check(PreShiftCheck.scooterBattery, testShift()), isNull);
    });

    test('arrival is within 100 m of the hub', () {
      final arrive = ArriveAtHub(repo);
      expect(arrive.isAtHub(testShift(), hubPoint), isTrue);
      expect(arrive.isAtHub(testShift(), nearHubPoint), isFalse);
    });
  });

  group('Home flow', () {
    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await settle(tester);
    }

    testWidgets('signing out clears the pushes', (tester) async {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.now = at(7, 30);
      await pumpApp(tester, fakes);
      expect(fakes.notifier.scheduled, isNotEmpty);
      fakes.auth.user.value = null;
      await settle(tester);
      expect(fakes.notifier.scheduled, isEmpty);
      expect(fakes.notifier.cancelled, containsAll(ShiftPush.values));
    });

    testWidgets('No shift today: Shift 02; its button does nothing until a shift arrives', (tester) async {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.now = at(7, 30);
      fakes.shifts.shift.value = null;
      await pumpApp(tester, fakes);
      expect(find.text('You’re off today'), findsOneWidget);
      expect(find.text('Not requested'), findsOneWidget);
      await tester.tap(find.text('Ask hub to prepare'));
      await settle(tester);
      expect(find.text('You’re off today'), findsOneWidget);

      fakes.shifts.shift.value = testShift();
      await settle(tester);
      expect(find.text('Stock not requested'), findsOneWidget);
    });

    testWidgets('push reply, hub packs, start riding, checklist, hub trip, stock empty', (tester) async {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.now = at(7, 30);
      await pumpApp(tester, fakes);
      expect(find.text('Stock not requested'), findsOneWidget);
      expect(fakes.notifier.scheduled.keys, containsAll([ShiftPush.prepareStock, ShiftPush.reminder]));

      // "I'm coming" on the push: the hub packs; the reminders go.
      fakes.notifier.tap(ShiftPushAction.coming);
      await settle(tester);
      expect(find.text('Hub is packing your stock'), findsOneWidget);
      expect(find.text('Starts at 9:00 AM'), findsOneWidget);
      expect(fakes.notifier.scheduled, isEmpty);

      fakes.shifts.shift.value = fakes.shifts.shift.value!.copyWith(stockRequest: StockRequestStatus.ready);
      await settle(tester);
      expect(find.text('Your stock is ready'), findsOneWidget);
      expect(fakes.notifier.shown, [ShiftPush.stockReady]);

      await tap(tester, find.text('Start riding'));
      expect(find.text('Before you start'), findsOneWidget);
      expect(find.text('Complete all checks to continue'), findsOneWidget);

      // Low phone battery can't be ticked.
      fakes.device.battery = 20;
      await tap(tester, find.byKey(const Key('check_phoneCharged')));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Complete all checks to continue'), findsOneWidget);
      fakes.device.battery = 90;
      for (final c in PreShiftCheck.values) {
        await tap(tester, find.byKey(Key('check_${c.name}')));
      }
      expect(find.text('All set. Head to the hub for your stock.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      await tap(tester, find.text('Go to hub'));
      expect(find.text('Heading to Hub 2'), findsOneWidget);
      expect(find.text('Turn right (1.2 km)'), findsOneWidget);

      // Back: Home 07; Go online without stock: Shift 51.
      final back = tester.binding.handlePopRoute();
      await back;
      await settle(tester);
      expect(find.text('Collect your stock'), findsOneWidget);
      await tap(tester, find.text('Go online'));
      expect(find.text('Load stock at the hub'), findsOneWidget);
      await tap(tester, find.text('Navigate to Hub 2'));
      expect(find.text('Heading to Hub 2'), findsOneWidget);

      // Arriving at the hub while it's still packing: Shift 53.
      fakes.shifts.shift.value = fakes.shifts.shift.value!.copyWith(stockRequest: StockRequestStatus.packing);
      fakes.tripPosition.value = hubPoint;
      await settle(tester);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.atHub);
      expect(find.text('Your stock at Hub 2'), findsOneWidget);
      expect(find.text('Waiting for the hub…'), findsOneWidget);
    });
  });
}
