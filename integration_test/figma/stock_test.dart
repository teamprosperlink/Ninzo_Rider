import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ninzo_rider/domain/entities/app_permission.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/shift.dart';
import 'package:ninzo_rider/data/datasources/local/local_stock_stores.dart';
import 'package:ninzo_rider/domain/entities/stock.dart';

import '../../test/fakes.dart';

/// Figma Section 8 (Stock scan; 16 frames): drives every state on a device
/// against fake repositories and a fake camera, and saves a screenshot named
/// after each Figma frame, to compare with the design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/stock_test.dart -d emulator-5554
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

  /// Lets a code go through the use cases: real async storage needs real time.
  Future<void> read(WidgetTester tester, Fakes fakes, String code) async {
    fakes.scanner.read(code);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await settle(tester);
  }

  final today = DateTime.now();
  DateTime at(int h, [int m = 0]) => DateTime(today.year, today.month, today.day, h, m);

  void frameSize(WidgetTester tester) {
    // Each test starts with a fresh surface.
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
    fakes.now = at(14, 14);
    fakes.permissions.status[AppPermission.camera] = PermissionResult.granted;
    fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: phase);
    return fakes;
  }

  testWidgets('Scanning with signal matches Figma', (tester) async {
    frameSize(tester);
    final fakes = rider(phase: ShiftPhase.atHub);
    fakes.stock.lots['B-2207'] = StockLot(id: 'B-2207', itemId: 'smash', expiresAt: at(13, 50));
    fakes.stock.lots['B-2209'] = const StockLot(id: 'B-2209', itemId: 'paneer', temperatureC: 12, maxTemperatureC: 8);
    await pumpApp(tester, fakes);

    await tap(tester, find.text('Scan stock'));
    expect(find.text('Point at the item QR code'), findsOneWidget);
    expect(find.text('0 of 6'), findsOneWidget);
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.scanning);

    await read(tester, fakes, testCode('paneer', 1));
    await read(tester, fakes, testCode('smash', 1));
    expect(find.text('Smash Burger added · 2 of 6'), findsOneWidget);
    expect(fakes.shifts.shift.value!.stock.scanned, 2, reason: 'Home follows the scans');

    // Expired lot, at 2:20 pm.
    fakes.now = at(14, 20);
    await read(tester, fakes, testCode('smash', 9, 'B-2207'));
    expect(find.text('LOT B-2207'), findsOneWidget);
    await shot(tester, 'stock_07_expired_lot');
    await tap(tester, find.text('Scan another item'));
    expect(find.text('2 of 6'), findsOneWidget, reason: 'an expired portion does not count');
    await shot(tester, 'stock_01_scan_item');

    // The camera stops working.
    fakes.scanner.fail();
    await settle(tester);
    expect(find.text('Turn on camera to scan'), findsOneWidget);
    expect(find.text('Manual'), findsNothing);
    await shot(tester, 'stock_09_camera_off');
    await tester.tap(find.text('Turn on camera to scan'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Point at the item QR code'), findsOneWidget);

    await read(tester, fakes, testCode('smash', 2));
    expect(find.text('Smash Burger added · 3 of 6'), findsOneWidget);
    await shot(tester, 'stock_02_item_scanned');

    await tap(tester, find.text('View list'));
    expect(find.text('Your stock'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    await shot(tester, 'stock_03_stock_list');
    await tap(tester, find.text('Scan next item'));

    await read(tester, fakes, 'some other label');
    expect(find.text('This item isn’t in today’s load'), findsOneWidget);
    await shot(tester, 'stock_04_not_on_list');
    await tap(tester, find.text('Scan again'));

    await read(tester, fakes, testCode('smash', 1));
    expect(find.text('This item is already scanned'), findsOneWidget);
    await shot(tester, 'stock_10_already_scanned');
    await tap(tester, find.text('Scan again'));

    await read(tester, fakes, testCode('smash', 3));
    expect(find.text('That’s more than today’s load'), findsOneWidget);
    await shot(tester, 'stock_11_more_than_today_s_load');
    await tap(tester, find.text('Scan again'));

    await read(tester, fakes, testCode('paneer', 9, 'B-2209'));
    expect(find.text('Temperature alert'), findsOneWidget);
    await shot(tester, 'stock_08_temperature_alert');
    await tap(tester, find.text('Move to quarantine'));
    expect(find.text('3 of 6'), findsOneWidget);
    expect(fakes.stock.quarantined, ['B-2209']);

    // The lot check takes a moment.
    final checking = fakes.stock.lotGate = Completer<void>();
    fakes.scanner.read(testCode('fries', 1));
    await settle(tester);
    expect(find.text('Checking item…'), findsOneWidget);
    await shot(tester, 'stock_12_checking_item');
    fakes.stock.lotGate = null;
    checking.complete();
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await settle(tester);
    expect(find.text('Peri Peri Fries added · 4 of 6'), findsOneWidget);

    await tap(tester, find.text('Manual'));
    expect(find.text('Enter counts'), findsOneWidget);
    await shot(tester, 'stock_05_manual_count');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Scan stock'), findsOneWidget, reason: 'back from counts');

    // Save counts → Stock 06.
    await tap(tester, find.text('Manual'));
    await tap(tester, find.text('Save counts'));
    await tester.pump(const Duration(milliseconds: 150));
    await settle(tester);
    expect(find.text('Stock confirmed'), findsOneWidget);
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.stockLoaded);
    expect(fakes.stock.uploaded.length, 6);
    await shot(tester, 'stock_06_stock_confirmed');

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Stock loaded'), findsOneWidget, reason: 'Shift 09');
    await tap(tester, find.text('Go online'));
    expect(find.text('Head to Yelahanka Node'), findsOneWidget, reason: 'Section 9 placeholder');
  });

  testWidgets('Scanning without signal matches Figma', (tester) async {
    frameSize(tester);
    final fakes = rider(phase: ShiftPhase.scanning);
    // Two scans already wait on the phone; the last sync was at 2:14 pm.
    await fakes.stockStore.save(
      'u1',
      fakes.shifts.shift.value!.id,
      StockLocalState(
        manifest: testStockManifest,
        lastSyncAt: at(14, 14),
        scans: [
          StockScan(code: testCode('smash', 1), itemId: 'smash', at: at(14, 15)),
          StockScan(code: testCode('smash', 2), itemId: 'smash', at: at(14, 15)),
        ],
      ),
    );
    fakes.signal.online = false;
    fakes.stock.failing = true;
    await pumpApp(tester, fakes);
    expect(find.text('2 of 6'), findsOneWidget);

    await read(tester, fakes, testCode('paneer', 1));
    expect(find.text('Scans saved'), findsOneWidget);
    await shot(tester, 'stock_13_scans_saved_offline');

    await tap(tester, find.text('Keep scanning'));
    await read(tester, fakes, testCode('paneer', 2));
    expect(find.text('Paneer Tikka Wrap added · 4 of 6'), findsOneWidget);
    await read(tester, fakes, testCode('fries', 1));
    await read(tester, fakes, testCode('coffee', 1));
    expect(find.text('All items scanned'), findsOneWidget);
    await shot(tester, 'stock_14_all_scanned_saved_offline');

    await tap(tester, find.text('View list'));
    expect(find.text('Saved offline'), findsOneWidget);
    await shot(tester, 'stock_16_stock_list_all_scanned_offline');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('All items scanned'), findsOneWidget, reason: 'Stock 16 back → 14');
    await tap(tester, find.text('View list'));

    // Signal back.
    fakes.stock.failing = false;
    fakes.signal.online = true;
    await tester.pump(const Duration(milliseconds: 150));
    await settle(tester);
    expect(find.text('Confirm stock'), findsOneWidget);
    expect(fakes.stock.uploaded.length, 6);
    await shot(tester, 'stock_15_stock_list_all_scanned');

    await tap(tester, find.text('Confirm stock'));
    await tester.pump(const Duration(milliseconds: 150));
    await settle(tester);
    expect(find.text('Stock confirmed'), findsOneWidget);
  });

  testWidgets('Offline scans survive a restart on the device', (tester) async {
    frameSize(tester);
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final fakes = rider(phase: ShiftPhase.scanning)..stockStore = PrefsStockScanStore();
    await pumpApp(tester, fakes);
    fakes.signal.online = false;
    await settle(tester);
    await read(tester, fakes, testCode('smash', 1));
    expect(find.text('Scans saved'), findsOneWidget);

    // Restart, still without signal or a backend.
    await tester.pumpWidget(const SizedBox());
    fakes.stock.failing = true;
    await pumpApp(tester, fakes);
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('1 of 6'), findsOneWidget);

    // Signal back: it syncs.
    fakes.stock.failing = false;
    fakes.signal.online = true;
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(fakes.stock.uploaded.map((s) => s.code), [testCode('smash', 1)]);
    await prefs.clear();
  });
}
