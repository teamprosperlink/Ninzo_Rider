import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/core/error/app_exception.dart';
import 'package:ninzo_rider/core/utils/formatters.dart';
import 'package:ninzo_rider/features/online/domain/entities/online_status.dart';
import 'package:ninzo_rider/features/online/domain/usecases/break_usecases.dart';
import 'package:ninzo_rider/features/online/domain/usecases/online_usecases.dart';
import 'package:ninzo_rider/features/online/domain/usecases/relocation_usecases.dart';
import 'package:ninzo_rider/features/refill/domain/entities/restock.dart';
import 'package:ninzo_rider/features/refill/domain/usecases/refill_usecases.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift.dart';

import 'fakes.dart';

void main() {
  const lines = [
    RestockLine(itemId: 'smash', name: 'Smash Burger', quantity: 4),
    RestockLine(itemId: 'paneer', name: 'Paneer Tikka Wrap', quantity: 0),
  ];
  const jakkur = Spot(name: 'Jakkur Node', point: LatLng(13.1095, 77.5960));
  const nudge = RelocationNudge(spot: jakkur, ordersWaiting: 3, meters: 450, rideMinutes: 3);
  final online = testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.online, scanned: 6);
  const order = AssignedOrder(id: 'A', number: 'A', gate: 'Gate 3', items: 1);

  group('Rules', () {
    test('Refill 01 at 1 left, Refill 02 at none; orders first; Stay online holds until out', () {
      expect(refillPromptOf(online, const OnlineStatus(sold: 4)), RefillPrompt.none);
      expect(refillPromptOf(online, const OnlineStatus(sold: 5)), RefillPrompt.lowStock);
      expect(refillPromptOf(online, const OnlineStatus(sold: 5), stayedOnline: true), RefillPrompt.none);
      expect(refillPromptOf(online, const OnlineStatus(sold: 6), stayedOnline: true), RefillPrompt.outOfStock);
      expect(refillPromptOf(online, const OnlineStatus(sold: 6, queue: [order])), RefillPrompt.none);
      expect(refillPromptOf(online, const OnlineStatus(sold: 6, stockAdded: 6)), RefillPrompt.none);
      expect(refillPromptOf(testShift(phase: ShiftPhase.atHub), const OnlineStatus(sold: 6)), RefillPrompt.none);
    });

    test('low stock banner at 5 or fewer, counting refills', () {
      expect(scooterStockOf(online, const OnlineStatus()).isLow, isFalse);
      expect(scooterStockOf(online, const OnlineStatus(sold: 1)).isLow, isTrue);
      expect(scooterStockOf(online, const OnlineStatus(sold: 6, stockAdded: 6)).portionsLeft, 6);
    });

    test('restock quantities: up to 8, never down to nothing', () {
      expect(RestockRules.canAdd(lines), isTrue);
      expect(RestockRules.canAdd([lines.first.withQuantity(8)]), isFalse);
      expect(RestockRules.canRemove(lines, 0), isTrue);
      expect(RestockRules.canRemove(lines, 1), isFalse);
      expect(RestockRules.canRemove([lines.first.withQuantity(1)], 0), isFalse);
      expect(RestockRules.headline(lines), '4 Smash Burgers');
      expect(RestockRules.headline([lines.first.withQuantity(1)]), '1 Smash Burger');
    });

    test('a suggestion expires; a confirmed restock does not', () {
      final at = DateTime(2026, 1, 1, 12);
      final request = RestockRequest(stage: RestockStage.suggested, hubName: 'Hub 2', lines: lines, expiresAt: at);
      expect(RestockRules.isExpired(request, at.subtract(const Duration(seconds: 1))), isFalse);
      expect(RestockRules.isExpired(request, at), isTrue);
      expect(RestockRules.isExpired(request.copyWith(stage: RestockStage.inProgress), at), isFalse);
    });

    test('the break clock, on time and over', () {
      final start = DateTime(2026, 1, 1, 12);
      final state = BreakState(startedAt: start, length: const Duration(minutes: 30));
      final soon = start.add(const Duration(seconds: 48));
      expect(minutesSeconds(state.left(soon).inSeconds), '29:12');
      expect(state.isOver(soon), isFalse);
      final late = start.add(const Duration(minutes: 32, seconds: 10));
      expect(state.isOver(late), isTrue);
      expect(minutesSeconds(state.left(late).inSeconds), '02:10');
      expect(state.progress(late), 1);
      expect(ordinal(3), '3rd');
      expect(ordinal(11), '11th');
    });

    test('the nudge is one banner among the others, under the shift ending', () {
      const select = SelectOnlineAlert();
      final now = online.end.subtract(const Duration(hours: 1));
      expect(
        select(shift: online, status: const OnlineStatus(sold: 1, nudge: nudge), now: now),
        isA<RelocationNudgeAlert>(),
      );
      expect(select(shift: online, status: OnlineStatus(nudge: nudge.covered), now: now), isA<NudgeCoveredAlert>());
      expect(select(shift: online, status: OnlineStatus(nudge: nudge.accepted(now)), now: now), isNull);
      expect(
        select(shift: online, status: const OnlineStatus(nudge: nudge), now: online.end.subtract(const Duration(minutes: 5))),
        isA<ShiftEndingAlert>(),
      );
    });
  });

  group('Use cases', () {
    late FakeShiftRepository shifts;
    late FakeOnlineRepository status;
    late FakeStockRepository stock;

    setUp(() {
      shifts = FakeShiftRepository()..shift.value = online;
      status = FakeOnlineRepository();
      stock = FakeStockRepository();
    });

    test('a refill is its own load; finishing adds what it held', () async {
      await StartRefill(shifts, stock)('u1', online);
      final refilling = shifts.shift.value!;
      expect(refilling.phase, ShiftPhase.atHub);
      expect(refilling.refill?.hubName, 'Hub 2');
      expect(refilling.stockLoadId, '${online.id}-refill1');

      await FinishRefill(shifts, status)('u1', refilling, 6);
      expect(status.status.value.stockAdded, 6);
      expect(shifts.shift.value!.refill, isNull);
      expect(shifts.shift.value!.phase, ShiftPhase.online);
      expect(shifts.shift.value!.stockLoadId, '${online.id}-refill1');
    });

    test('only an online rider starts a refill; cancelling goes back online', () async {
      expect(
        () => StartRefill(shifts, stock)('u1', testShift(phase: ShiftPhase.atHub)),
        throwsA(isA<AppException>()),
      );
      await StartRefill(shifts, stock)('u1', online);
      await CancelRefill(shifts)('u1', shifts.shift.value!);
      expect(shifts.shift.value!.phase, ShiftPhase.online);
      expect(shifts.shift.value!.refill, isNull);
    });

    test('restock: the hub is short, on to the refill with what was asked', () async {
      final answer = AnswerRestock(status, StartRefill(shifts, stock));
      const request = RestockRequest(
        stage: RestockStage.hubShort,
        hubName: 'Hub 2',
        lines: lines,
        shortage: RestockShortage(
          itemName: 'Smash Burger',
          asked: 4,
          canGive: 2,
          otherHubName: 'Hub 4',
          otherHubKm: 2.1,
          otherHubHas: 4,
        ),
      );
      await answer.takeWhatHubHas('u1', online.id, request);
      expect(status.status.value.restock!.stage, RestockStage.inProgress);
      expect(status.status.value.restock!.lines.first.quantity, 2);

      await answer.tryOtherHub('u1', online.id, request);
      expect(status.status.value.restock!.hubName, 'Hub 4');
      expect(status.status.value.restock!.lines.first.quantity, 4);

      await answer.headToHub('u1', online, status.status.value.restock!);
      expect(status.status.value.restock, isNull);
      expect(shifts.shift.value!.refill?.hubName, 'Hub 4');
      expect(stock.prepared['${online.id}-refill1']!.single.quantity, 4);

      expect(() => answer.confirm('u1', online.id, request, const []), throwsA(isA<AppException>()));
    });

    test('taking a nudge makes it the rider spot and heads there', () async {
      final at = DateTime(2026, 1, 1, 12);
      await AnswerRelocation(status, shifts, () => at).accept('u1', online, nudge);
      expect(status.status.value.nudge!.stage, NudgeStage.accepted);
      expect(status.status.value.nudge!.acceptedAt, at);
      expect(shifts.shift.value!.spot.name, 'Jakkur Node');
      expect(shifts.shift.value!.phase, ShiftPhase.headingToSpot);
    });

    test('a break needs no orders waiting; +15 min and back online', () async {
      final at = DateTime(2026, 1, 1, 12);
      final take = TakeBreak(status, () => at);
      expect(
        () => take.start('u1', online, const OnlineStatus(queue: [order]), BreakOption.min30),
        throwsA(isA<AppException>()),
      );
      await take.start('u1', online, const OnlineStatus(), BreakOption.min30);
      final state = status.status.value.breakState!;
      expect(state.length, const Duration(minutes: 30));
      await take.extend('u1', online.id, state);
      expect(status.status.value.breakState!.length, const Duration(minutes: 45));
      await take.end('u1', online.id);
      expect(status.status.value.breakState, isNull);
    });
  });

  group('Screens', () {
    Fakes rider({OnlineStatus status = const OnlineStatus()}) {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
      final today = DateTime.now();
      fakes.now = DateTime(today.year, today.month, today.day, 10);
      fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: ShiftPhase.online, scanned: 6);
      fakes.riderLocation.position.value = const Distance().offset(const LatLng(13.1052, 77.5921), 30, 119.4);
      fakes.online.status.value = status;
      return fakes;
    }

    Future<void> tap(WidgetTester tester, String text) async {
      await tester.ensureVisible(find.text(text).last);
      await tester.tap(find.text(text).last);
      await settle(tester);
    }

    Future<void> setSize(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(800, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('Low stock: Stay online holds until out; out to the hub and back', (tester) async {
      await setSize(tester);
      final fakes = rider(status: const OnlineStatus(sold: 5, itemsLeft: [ItemLeft(name: 'Paneer Tikka Wrap', left: 1)]));
      await pumpApp(tester, fakes);
      expect(find.text('Only 1 item left'), findsOneWidget);
      await tap(tester, 'Stay online');
      expect(find.text('Waiting for orders'), findsOneWidget);

      fakes.online.status.value = fakes.online.status.value.copyWith(sold: 6);
      await settle(tester);
      expect(find.text('Time to refill'), findsOneWidget);
      await tap(tester, 'Navigate to hub');
      expect(find.text('Refill at Hub 2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.text('Time to refill'), findsOneWidget);
    });

    testWidgets('Restock: Not now and Back to waiting reach the map; Ask for a restock does nothing', (tester) async {
      await setSize(tester);
      final fakes = rider(
        status: const OnlineStatus(
          restock: RestockRequest(stage: RestockStage.suggested, hubName: 'Hub 2', lines: lines),
        ),
      );
      await pumpApp(tester, fakes);
      await tap(tester, 'Not now');
      expect(fakes.online.status.value.restock, isNull);
      expect(find.text('Waiting for orders'), findsOneWidget);

      fakes.online.status.value = fakes.online.status.value.copyWith(
        restock: () => RestockRequest(
          stage: RestockStage.suggested,
          hubName: 'Hub 2',
          lines: lines,
          expiresAt: fakes.now!.subtract(const Duration(minutes: 1)),
        ),
      );
      await settle(tester);
      expect(find.text('That suggestion ran out'), findsOneWidget);
      await tap(tester, 'Ask for a restock');
      expect(find.text('That suggestion ran out'), findsOneWidget);
      await tap(tester, 'Back to waiting');
      expect(find.text('Waiting for orders'), findsOneWidget);
    });

    testWidgets('Edit quantity: plus moves the number, confirm carries it to Restock 03', (tester) async {
      await setSize(tester);
      final fakes = rider(
        status: const OnlineStatus(
          restock: RestockRequest(stage: RestockStage.suggested, hubName: 'Hub 2', lines: lines),
        ),
      );
      await pumpApp(tester, fakes);
      await tap(tester, 'Edit quantity');
      await tester.tap(find.text('+').last);
      await settle(tester);
      await tap(tester, 'Confirm restock');
      final restock = fakes.online.status.value.restock!;
      expect(restock.stage, RestockStage.inProgress);
      expect(restock.lines.map((l) => l.quantity), [4, 1]);
      expect(find.text('Restock at Hub 2'), findsOneWidget);
      await tap(tester, 'Cancel restock');
      expect(fakes.online.status.value.restock, isNull);
    });

    testWidgets('Hub is short: Take 2 and Try Hub 4 lead to Restock 03', (tester) async {
      await setSize(tester);
      final fakes = rider(
        status: const OnlineStatus(
          restock: RestockRequest(stage: RestockStage.inProgress, hubName: 'Hub 2', lines: lines),
        ),
      );
      await pumpApp(tester, fakes);
      expect(find.text('Head to Hub 2'), findsOneWidget);
      final inProgress = fakes.online.status.value.restock!;
      fakes.online.status.value = fakes.online.status.value.copyWith(
        restock: () => RestockRequest(
          stage: RestockStage.suggested,
          hubName: 'Hub 2',
          lines: lines,
          expiresAt: fakes.now!.subtract(const Duration(minutes: 1)),
        ),
      );
      await settle(tester);
      expect(find.text('That suggestion ran out'), findsOneWidget);
      fakes.online.status.value = fakes.online.status.value.copyWith(
        restock: () => inProgress.copyWith(
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
      await settle(tester);
      expect(find.text('Hub 2 has 2 of 4 Smash Burgers right now.'), findsOneWidget);
      await tap(tester, 'Try Hub 4');
      expect(find.text('Head to Hub 4'), findsOneWidget);
    });

    testWidgets('Nudge: Not now clears it; Got it clears the covered one', (tester) async {
      await setSize(tester);
      final fakes = rider(status: const OnlineStatus(nudge: nudge));
      await pumpApp(tester, fakes);
      expect(find.text('Orders waiting at Jakkur Node'), findsOneWidget);
      await tap(tester, 'Not now');
      expect(fakes.online.status.value.nudge, isNull);
      fakes.online.status.value = fakes.online.status.value.copyWith(nudge: () => nudge.covered);
      await settle(tester);
      await tap(tester, 'Got it');
      expect(fakes.online.status.value.nudge, isNull);
    });

    testWidgets('Break: choose, start, +15 min, End shift; Cancel goes back', (tester) async {
      await setSize(tester);
      final fakes = rider();
      await pumpApp(tester, fakes);
      await tap(tester, 'Take a break');
      await tap(tester, 'Cancel');
      expect(find.text('Waiting for orders'), findsOneWidget);
      await tap(tester, 'Take a break');
      await tap(tester, '45 min');
      await tap(tester, 'Start break');
      expect(fakes.online.status.value.breakState!.length, const Duration(minutes: 45));
      expect(find.text('Enjoy your break'), findsOneWidget);
      await tap(tester, '+15 min');
      expect(find.text('of 60 min break'), findsOneWidget);
      await tap(tester, 'End shift');
      expect(find.text('End your shift?'), findsOneWidget);
    });
  });
}
