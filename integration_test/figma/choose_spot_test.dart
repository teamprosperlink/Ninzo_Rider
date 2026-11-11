import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ninzo_rider/presentation/online/viewmodels/choose_spot_view_model.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';

import '../../test/fakes.dart';

/// Figma Section 24 (Choose a spot, Shift 13–18; 6 frames): drives every state
/// on a device against fake repositories, and saves a screenshot named after
/// each Figma frame, to compare with the design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/choose_spot_test.dart -d emulator-5554
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceReady = false;

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    // Let tap ripples fade.
    await tester.pump(const Duration(milliseconds: 700));
    if (Platform.isAndroid && !surfaceReady) {
      await binding.convertFlutterSurfaceToImage();
      surfaceReady = true;
      await tester.pump();
    }
    await binding.takeScreenshot(name);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  final today = DateTime.now();

  testWidgets('Shift 13–18 match Figma', (tester) async {
    // Lay out at the Figma frame size, 360 × 800 with a 48px status bar.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 144, bottom: 48)
      ..viewPadding = const FakeViewPadding(top: 144, bottom: 48);
    addTearDown(tester.view.reset);

    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
    fakes.now = DateTime(today.year, today.month, today.day, 9, 41);
    fakes.shifts.shift.value = testShift(
      stockRequest: StockRequestStatus.ready,
      phase: ShiftPhase.stockLoaded,
      scanned: 6,
    );
    final spots = fakes.spotChoices;
    await pumpApp(tester, fakes);
    final vm = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    ).read(chooseSpotViewModelProvider.notifier);

    // No flow-map arrow leads here: the demo pill opens it in the app.
    spots.findGate = Completer<void>();
    vm.open();
    await settle(tester);
    expect(find.text('Finding spots near you…'), findsOneWidget);
    await shot(tester, 'shift_13_choose_a_spot_finding_spots');

    spots.findGate!.complete();
    spots.findGate = null;
    await settle(tester);
    expect(find.text('Choose a spot'), findsOneWidget);
    await shot(tester, 'shift_14_choose_a_spot_nothing_selected');

    await tap(tester, 'Yelahanka Node');
    expect(find.text('Go to Yelahanka Node'), findsOneWidget);
    await shot(tester, 'shift_15_choose_a_spot');

    spots.claimGate = Completer<void>();
    spots.taken.add('Yelahanka Node');
    await tap(tester, 'Go to Yelahanka Node');
    expect(find.text('Confirming spot…'), findsOneWidget);
    await shot(tester, 'shift_16_choose_a_spot_confirming');

    // Another rider got there first.
    spots.claimGate!.complete();
    spots.claimGate = null;
    await settle(tester);
    expect(find.text('Yelahanka Node just filled up. Another rider got the last spot.'), findsOneWidget);
    expect(find.text('Hebbal Node'), findsNothing);
    await shot(tester, 'shift_17_spot_is_full');

    // Nothing free.
    final all = spots.spots;
    spots.spots = [for (final s in all) s.filled];
    await tap(tester, 'Refresh');
    await settle(tester);
    expect(find.text('No spot available right now'), findsOneWidget);
    await shot(tester, 'shift_18_no_spot_available');

    // Check again finds spots again, and the arrow out: Spot confirmed → Shift 19.
    spots.spots = all;
    spots.taken.clear();
    await tap(tester, 'Check again');
    await settle(tester);
    await tap(tester, 'Jakkur Node');
    await tap(tester, 'Go to Jakkur Node');
    await settle(tester);
    expect(fakes.shifts.shift.value!.spot.name, 'Jakkur Node');
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.headingToSpot);
    expect(find.text('Head to Jakkur Node'), findsOneWidget);
  });
}
