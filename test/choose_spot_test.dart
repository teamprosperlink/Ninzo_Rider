import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/domain/entities/spot_option.dart';
import 'package:ninzo_rider/domain/usecases/choose_spot_usecases.dart';
import 'package:ninzo_rider/presentation/online/viewmodels/choose_spot_view_model.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';

import 'fakes.dart';

SpotOption spot(String name, double km, int taken) =>
    SpotOption(name: name, km: km, taken: taken, capacity: 3, point: const LatLng(13.1, 77.6));

void main() {
  group('SpotOption', () {
    test('tags as the frames draw them; two riders has no frame', () {
      expect(spot('a', 1, 0).tag, SpotTag.bestForOrders);
      expect(spot('a', 1, 1).tag, SpotTag.recommended);
      expect(spot('a', 1, 2).tag, isNull);
      expect(spot('a', 1, 3).tag, SpotTag.full);
    });

    test('filled takes the last place', () {
      final filled = spot('a', 1, 1).filled;
      expect(filled.isFull, isTrue);
      expect(filled.taken, 3);
      expect(filled.fullness, 1);
    });
  });

  group('Rules and use cases', () {
    test('afterFilled: the filled spot first, then the free ones only', () {
      final all = [spot('Jakkur', 0.9, 0), spot('Yelahanka', 1.2, 1), spot('Hebbal', 2.4, 3)];
      final after = SpotChoiceRules.afterFilled(all, all[1].filled);
      expect(after.map((s) => s.name), ['Yelahanka', 'Jakkur']);
      expect(after.first.isFull, isTrue);
    });

    test('anyFree', () {
      expect(SpotChoiceRules.anyFree([spot('a', 1, 3), spot('b', 2, 2)]), isTrue);
      expect(SpotChoiceRules.anyFree([spot('a', 1, 3)]), isFalse);
      expect(SpotChoiceRules.anyFree(const []), isFalse);
    });

    test('FindSpots: nearest first', () async {
      final found = await FindSpots(FakeSpotChoices())('u1');
      expect(found.map((s) => s.name), ['Jakkur Node', 'Yelahanka Node', 'Hebbal Node']);
    });

    test('ConfirmSpot: moves the rider only when the claim holds', () async {
      final choices = FakeSpotChoices()..taken.add('a');
      final shifts = FakeShiftRepository();
      final confirm = ConfirmSpot(choices, shifts);
      final before = shifts.shift.value!;
      expect(await confirm('u1', before, spot('a', 1, 1)), ConfirmSpotResult.spotFull);
      expect(shifts.shift.value!.spot.name, before.spot.name);
      expect(await confirm('u1', before, spot('b', 1, 1)), ConfirmSpotResult.confirmed);
      expect(shifts.shift.value!.spot.name, 'b');
    });
  });

  group('Screen', () {
    Future<(Fakes, ChooseSpotViewModel)> open(WidgetTester tester, {void Function(Fakes)? setUp}) async {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
      fakes.shifts.shift.value = testShift(
        stockRequest: StockRequestStatus.ready,
        phase: ShiftPhase.stockLoaded,
        scanned: 6,
      );
      setUp?.call(fakes);
      await pumpApp(tester, fakes);
      final vm = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      ).read(chooseSpotViewModelProvider.notifier);
      vm.open();
      await settle(tester);
      return (fakes, vm);
    }

    Future<void> tap(WidgetTester tester, String text) async {
      await tester.tap(find.text(text).last);
      await settle(tester);
    }

    bool enabledButton(WidgetTester tester, String label) =>
        tester.widget<InkWell>(find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first).onTap != null;

    testWidgets('Without the pill the app stays on Home: nothing else leads here', (tester) async {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.shifts.shift.value = testShift(
        stockRequest: StockRequestStatus.ready,
        phase: ShiftPhase.stockLoaded,
        scanned: 6,
      );
      await pumpApp(tester, fakes);
      expect(find.text('Stock loaded'), findsOneWidget);
      expect(find.text('Demo: Choose a spot'), findsNothing);
      await tap(tester, 'Go online');
      await settle(tester);
      expect(find.text('Where to wait'), findsNothing);
      expect(find.text('Head to Yelahanka Node'), findsOneWidget);
    });

    testWidgets('Shift 13 → 14 → 15 → 16 → Shift 19', (tester) async {
      final gate = Completer<void>();
      final (fakes, _) = await open(tester, setUp: (f) => f.spotChoices.findGate = gate);
      expect(find.text('Finding spots near you…'), findsOneWidget);
      expect(enabledButton(tester, 'Finding spots…'), isFalse);

      gate.complete();
      await settle(tester);
      expect(find.text('Pick a spot to wait at. Fewer riders means more orders for you.'), findsOneWidget);
      expect(enabledButton(tester, 'Choose a spot'), isFalse);
      expect(find.text('Best for orders'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Full'), findsOneWidget);

      // A full spot can't be picked.
      await tap(tester, 'Hebbal Node');
      expect(find.text('Choose a spot'), findsOneWidget);

      await tap(tester, 'Yelahanka Node');
      expect(enabledButton(tester, 'Go to Yelahanka Node'), isTrue);

      fakes.spotChoices.claimGate = Completer<void>();
      await tap(tester, 'Go to Yelahanka Node');
      expect(find.text('Confirming spot…'), findsOneWidget);
      // The back arrow waits while it's confirming.
      await tester.tap(find.bySemanticsLabel('Back'));
      await settle(tester);
      expect(find.text('Confirming spot…'), findsOneWidget);

      fakes.spotChoices.claimGate!.complete();
      await settle(tester);
      expect(fakes.spotChoices.claims, ['Yelahanka Node']);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.headingToSpot);
      expect(find.text('Head to Yelahanka Node'), findsOneWidget);
    });

    testWidgets('Shift 17 when the spot fills up; Go to → the free one; Refresh looks again', (tester) async {
      final (fakes, vm) = await open(tester);
      vm.spotFilled(fakes.spotChoices.spots[2]);
      await settle(tester);
      expect(find.text('Yelahanka Node just filled up. Another rider got the last spot.'), findsOneWidget);
      expect(find.text('3 of 3 spots taken'), findsOneWidget);
      expect(find.text('Hebbal Node'), findsNothing);
      // Cards can't be picked here.
      await tap(tester, 'Yelahanka Node');
      expect(find.text('Go to Jakkur Node'), findsOneWidget);

      await tap(tester, 'Refresh');
      expect(find.text('Choose a spot'), findsOneWidget);

      vm.spotFilled(fakes.spotChoices.spots[2]);
      await settle(tester);
      await tap(tester, 'Go to Jakkur Node');
      expect(fakes.spotChoices.claims, ['Jakkur Node']);
      expect(fakes.shifts.shift.value!.spot.name, 'Jakkur Node');
    });

    testWidgets('A refused claim is Shift 17; with nothing else free, Shift 18', (tester) async {
      final (fakes, _) = await open(tester, setUp: (f) => f.spotChoices.taken.addAll(['Yelahanka Node', 'Jakkur Node']));
      await tap(tester, 'Yelahanka Node');
      await tap(tester, 'Go to Yelahanka Node');
      expect(find.text('Yelahanka Node just filled up. Another rider got the last spot.'), findsOneWidget);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.stockLoaded);

      await tap(tester, 'Go to Jakkur Node');
      expect(find.text('No spot available right now'), findsOneWidget);
    });

    testWidgets('Shift 18 when nothing is free; Check again looks again', (tester) async {
      final (fakes, _) = await open(
        tester,
        setUp: (f) => f.spotChoices.spots = [for (final s in f.spotChoices.spots) s.filled],
      );
      expect(find.text('NO SPOT FREE'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);

      fakes.spotChoices.spots = [spot('Jakkur Node', 0.9, 0)];
      await tap(tester, 'Check again');
      expect(find.text('Choose a spot'), findsOneWidget);
    });

    testWidgets('A failed claim stays on the choice, with no message', (tester) async {
      final (fakes, _) = await open(tester);
      fakes.spotChoices.failClaim = true;
      await tap(tester, 'Jakkur Node');
      await tap(tester, 'Go to Jakkur Node');
      expect(find.text('Go to Jakkur Node'), findsOneWidget);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.stockLoaded);
    });

    testWidgets('No signal after the claim stays on the choice', (tester) async {
      final (fakes, _) = await open(tester);
      fakes.signal.online = false;
      await tap(tester, 'Jakkur Node');
      await tap(tester, 'Go to Jakkur Node');
      expect(find.text('Go to Jakkur Node'), findsOneWidget);
      expect(fakes.shifts.shift.value!.phase, ShiftPhase.stockLoaded);
    });

    testWidgets('A failed search stays on Shift 13 and looks again; back goes Home', (tester) async {
      final (fakes, _) = await open(tester, setUp: (f) => f.spotChoices.failFind = true);
      expect(find.text('Finding spots near you…'), findsOneWidget);
      fakes.spotChoices.failFind = false;
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(find.text('Choose a spot'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back'));
      await settle(tester);
      expect(find.text('Stock loaded'), findsOneWidget);
    });
  });
}
