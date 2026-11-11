import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ninzo_rider/core/theme/app_theme.dart';
import 'package:ninzo_rider/domain/entities/app_permission.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/pre_shift_check.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';
import 'package:ninzo_rider/domain/entities/shift_push.dart';
import 'package:ninzo_rider/presentation/shift/widgets/push_preview.dart';

import '../../test/fakes.dart';

/// Figma Sections 4–7 (morning stock request pushes, Home daily states,
/// Before you start, hub trip; 18 frames): drives every state on a device
/// against fake repositories and saves a screenshot named after each Figma
/// frame, to compare with the design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/home_test.dart -d emulator-5554
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceReady = false;

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    // Let tap ripples fade so they don't show in the screenshot.
    await tester.pump(const Duration(milliseconds: 700));
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

  final today = DateTime.now();
  DateTime at(int h, [int m = 0]) => DateTime(today.year, today.month, today.day, h, m);

  testWidgets('Home, checklist and hub trip match Figma', (tester) async {
    // Lay out at the Figma frame size, 360 × 800 with a 48px status bar.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 144, bottom: 48)
      ..viewPadding = const FakeViewPadding(top: 144, bottom: 48);
    addTearDown(tester.view.reset);

    // ── Section 4: the pushes, on the lock screen (Tuesday, 3 November, 9:41) ──
    for (final (push, name) in [
      (ShiftPush.prepareStock, 'notification_05_prepare_your_stock_push'),
      (ShiftPush.reminder, 'notification_06_reminder_tell_the_hub_push'),
      (ShiftPush.stockReady, 'notification_07_stock_ready_push'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: ShiftPushPreview(push: push, shift: testShift(), now: DateTime(2026, 11, 3, 9, 41)),
        ),
      );
      await settle(tester);
      expect(find.text(ShiftPushContent.of(push, testShift()).title), findsOneWidget);
      await shot(tester, name);
    }

    // ── Section 5: Home ──
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
    fakes.now = at(8);
    final shifts = fakes.shifts;
    void update(Shift Function(Shift s) change) => shifts.shift.value = change(shifts.shift.value!);
    await pumpApp(tester, fakes);
    expect(fakes.notifier.scheduled.keys, containsAll([ShiftPush.prepareStock, ShiftPush.reminder]));

    expect(find.text('Stock not requested'), findsOneWidget);
    await shot(tester, 'shift_01_home_no_stock_requested');

    fakes.notifier.tap(ShiftPushAction.notToday);
    await settle(tester);
    expect(find.text('You’re off today'), findsOneWidget);
    await shot(tester, 'shift_02_home_not_working_today');

    await tap(tester, find.text('Ask hub to prepare'));
    expect(find.text('Hub is packing your stock'), findsOneWidget);
    await shot(tester, 'shift_03_home_hub_preparing');

    update((s) => s.copyWith(stockRequest: StockRequestStatus.ready));
    await settle(tester);
    expect(find.text('Your stock is ready'), findsOneWidget);
    expect(fakes.notifier.shown, [ShiftPush.stockReady]);
    await shot(tester, 'shift_04_home_stock_ready');

    // The shift begins.
    fakes.now = at(9, 5);
    update((s) => s.copyWith());
    await settle(tester);
    expect(find.text('You’re offline'), findsOneWidget);
    await shot(tester, 'shift_05_home_start_riding');

    final starting = shifts.phaseGate = Completer<void>();
    await tap(tester, find.text('Start riding'));
    expect(find.text('Starting…'), findsOneWidget);
    await shot(tester, 'shift_06_home_starting');
    starting.complete();
    await settle(tester);

    // ── Section 6: Before you start ──
    expect(find.text('Complete all checks to continue'), findsOneWidget);
    await shot(tester, 'shift_10_pre_shift_checklist_none_checked');

    for (final c in PreShiftCheck.values.take(4)) {
      await tap(tester, find.byKey(Key('check_${c.name}')));
    }
    await shot(tester, 'shift_11_pre_shift_checklist');

    for (final c in PreShiftCheck.values.skip(4)) {
      await tap(tester, find.byKey(Key('check_${c.name}')));
    }
    expect(find.text('All set. Head to the hub for your stock.'), findsOneWidget);
    await shot(tester, 'shift_12_pre_shift_checklist_all_checked');

    // ── Section 7: Hub trip ──
    await tap(tester, find.text('Go to hub'));
    expect(find.text('Heading to Hub 2'), findsOneWidget);
    // Map tiles load from the network.
    await tester.pump(const Duration(seconds: 3));
    await shot(tester, 'shift_52_heading_to_hub');

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Collect your stock'), findsOneWidget);
    await shot(tester, 'shift_07_home_collect_stock_at_hub');

    await tap(tester, find.text('Go online'));
    expect(find.text('Load stock at the hub'), findsOneWidget);
    await shot(tester, 'shift_51_stock_empty_offline');

    // Arrive while the hub is still packing.
    await tap(tester, find.text('Navigate to Hub 2'));
    update((s) => s.copyWith(stockRequest: StockRequestStatus.packing, stockReadyAt: () => at(9, 14)));
    fakes.tripPosition.value = hubPoint;
    await settle(tester);
    expect(find.text('Your stock at Hub 2'), findsOneWidget);
    expect(find.text('About 9 min'), findsOneWidget);
    await shot(tester, 'shift_53_at_hub_hub_is_packing');

    // The hub finishes; scan half the stock (Section 8), then back to Home.
    update((s) => s.copyWith(stockRequest: StockRequestStatus.ready));
    await settle(tester);
    await tap(tester, find.text('Scan stock'));
    fakes.permissions.status[AppPermission.camera] = PermissionResult.granted;
    Future<void> read(String code) async {
      fakes.scanner.read(code);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 150));
      await settle(tester);
    }

    await read(testCode('smash', 1));
    await read(testCode('smash', 2));
    await read(testCode('paneer', 1));
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Finish scanning your stock'), findsOneWidget);
    expect(find.text('3 of 6 portions'), findsOneWidget);
    await shot(tester, 'shift_08_home_finish_scanning');

    await tap(tester, find.text('Continue scanning'));
    await read(testCode('paneer', 2));
    await read(testCode('fries', 1));
    await read(testCode('coffee', 1));
    await tap(tester, find.text('Confirm stock'));
    await tester.pump(const Duration(milliseconds: 150));
    await settle(tester);
    expect(find.text('Stock confirmed'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Stock loaded'), findsOneWidget);
    await shot(tester, 'shift_09_home_stock_loaded');
  });
}
