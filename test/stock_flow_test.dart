import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ninzo_rider/features/intro/domain/entities/app_permission.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift.dart';
import 'package:ninzo_rider/features/stock/domain/entities/stock.dart';

import 'fakes.dart';

/// Where the buttons of the stock screens lead (flow map 7, 8, 8b).
void main() {
  Fakes rider({ShiftPhase phase = ShiftPhase.scanning, bool camera = true}) {
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    fakes.permissions.status[AppPermission.camera] = camera ? PermissionResult.granted : PermissionResult.denied;
    fakes.permissions.denyRequests = !camera;
    fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: phase);
    return fakes;
  }

  Future<void> pumpTall(WidgetTester tester, Fakes fakes) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(tester, fakes);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settle(tester);
  }

  Future<void> read(WidgetTester tester, Fakes fakes, String code) async {
    fakes.scanner.read(code);
    await settle(tester);
  }

  final allCodes = [
    testCode('smash', 1),
    testCode('smash', 2),
    testCode('paneer', 1),
    testCode('paneer', 2),
    testCode('fries', 1),
    testCode('coffee', 1),
  ];

  testWidgets('Scan → list → confirm → Go online; back from list and 06 leads Home', (tester) async {
    final fakes = rider();
    await pumpTall(tester, fakes);
    expect(find.text('Scan stock'), findsOneWidget);
    expect(find.text('0 of 6'), findsOneWidget);

    await read(tester, fakes, allCodes[0]);
    expect(find.text('Smash Burger added · 1 of 6'), findsOneWidget);

    await tap(tester, 'View list');
    expect(find.text('Your stock'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Scan next item'), findsOneWidget);

    // Stock 03 back → Shift 08, counting the scan.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('1 of 6 portions'), findsOneWidget);

    await tap(tester, 'Continue scanning');
    expect(find.text('Scan stock'), findsOneWidget);
    for (final code in allCodes.skip(1)) {
      await read(tester, fakes, code);
    }

    // Last item scanned: Stock 15.
    expect(find.text('Items loaded'), findsOneWidget);
    expect(find.text('4 of 4'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tap(tester, 'Continue scanning');
    expect(find.text('Confirm stock'), findsOneWidget, reason: 'nothing left to scan');

    await tap(tester, 'Confirm stock');
    await settle(tester);
    expect(find.text('Stock confirmed'), findsOneWidget);
    expect(find.text('4 items loaded. You’re ready to go online.'), findsOneWidget);
    await tap(tester, 'Go online');
    expect(find.text('Head to Yelahanka Node'), findsOneWidget);
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.headingToSpot);
  });

  testWidgets('Warnings block scanning until Scan again; camera sees nothing meanwhile', (tester) async {
    final fakes = rider();
    await pumpTall(tester, fakes);
    await read(tester, fakes, 'nonsense');
    expect(find.text('This item isn’t in today’s load'), findsOneWidget);
    expect(find.text('View list'), findsNothing);

    await read(tester, fakes, allCodes[0]);
    expect(find.text('This item isn’t in today’s load'), findsOneWidget, reason: 'ignored');

    await tap(tester, 'Scan again');
    expect(find.text('0 of 6'), findsOneWidget);
    await read(tester, fakes, allCodes[0]);
    expect(find.text('Smash Burger added · 1 of 6'), findsOneWidget);
  });

  testWidgets('Without camera access: Stock 09, Enter counts instead; incomplete counts go to the list', (tester) async {
    final fakes = rider(camera: false);
    await pumpTall(tester, fakes);
    expect(find.text('Turn on camera to scan'), findsOneWidget);
    expect(find.text('Allow camera access to scan, or enter counts by hand.'), findsOneWidget);
    expect(find.text('Manual'), findsNothing);

    await tap(tester, 'Enter counts instead');
    expect(find.text('Enter counts'), findsOneWidget);
    // Start from what was packed; one fries short.
    await tester.tap(find.bySemanticsLabel('Fewer').at(2));
    await settle(tester);
    await tap(tester, 'Save counts');
    await settle(tester);
    expect(find.text('5 of 6'), findsOneWidget);
    expect(find.text('Scan next item'), findsOneWidget);
    expect(fakes.shifts.shift.value!.phase, ShiftPhase.scanning);
    expect(fakes.stock.uploaded.every((s) => s.method == ScanMethod.manual), isTrue);
  });

  testWidgets('Offline counts: complete counts wait on Stock 14; signal back goes to Stock 06', (tester) async {
    final fakes = rider();
    await pumpTall(tester, fakes);
    fakes.signal.online = false;
    await settle(tester);

    await tap(tester, 'Manual');
    await tap(tester, 'Save counts');
    await settle(tester);
    expect(find.text('All items scanned'), findsOneWidget);
    expect(find.text('6 scans'), findsOneWidget);
    expect(fakes.stock.uploaded, isEmpty);

    fakes.signal.online = true;
    await settle(tester);
    await settle(tester);
    expect(find.text('Stock confirmed'), findsOneWidget);
    expect(fakes.stock.uploaded.length, 6);
  });

  testWidgets('Offline: Stock 13 once, then toasts; signal back returns to the scanner', (tester) async {
    final fakes = rider();
    await pumpTall(tester, fakes);
    fakes.signal.online = false;
    await settle(tester);

    await read(tester, fakes, allCodes[0]);
    expect(find.text('Scans saved'), findsOneWidget);
    await tap(tester, 'Keep scanning');
    await read(tester, fakes, allCodes[1]);
    expect(find.text('Smash Burger added · 2 of 6'), findsOneWidget);
    expect(fakes.stock.uploaded, isEmpty);

    // Home counts what waits on the phone.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('2 of 6 portions'), findsOneWidget);
    await tap(tester, 'Continue scanning');

    await read(tester, fakes, allCodes[2]);
    expect(find.text('Paneer Tikka Wrap added · 3 of 6'), findsOneWidget);

    fakes.signal.online = true;
    await settle(tester);
    await settle(tester);
    expect(fakes.stock.uploaded.length, 3);
    expect(fakes.shifts.shift.value!.stock.scanned, 3);

    // Dropped again and back while on Stock 13.
    fakes.signal.online = false;
    await settle(tester);
    await read(tester, fakes, allCodes[3]);
    expect(find.text('Scans saved'), findsOneWidget);
    fakes.signal.online = true;
    await settle(tester);
    await settle(tester);
    expect(find.text('4 of 6'), findsOneWidget);
    expect(find.text('Scans saved'), findsNothing);
  });

  testWidgets('A failed load goes back to Home, and opening it again retries', (tester) async {
    final fakes = rider();
    fakes.stock.failing = true;
    await pumpTall(tester, fakes);
    expect(find.text('Scan stock'), findsNothing);
    expect(find.text('Continue scanning'), findsOneWidget);
    await tap(tester, 'Continue scanning');
    await settle(tester);
    await settle(tester);
    // Still no list: back on Home, not stuck on a blank screen.
    expect(find.text('Continue scanning'), findsOneWidget);
    fakes.stock.failing = false;
    await tap(tester, 'Continue scanning');
    await settle(tester);
    await settle(tester);
    expect(find.text('Scan stock'), findsOneWidget);
  });
}
