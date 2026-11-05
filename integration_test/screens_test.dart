import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ninzo_rider/core/widgets/rider/rider_ui.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/orders/domain/entities/order.dart';

import '../test/fakes.dart';

/// Walks a rider through every screen on a real device, against fake
/// repositories, and saves a screenshot of each one.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/screens_test.dart -d <device>
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceReady = false;

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    if (Platform.isAndroid && !surfaceReady) {
      await binding.convertFlutterSurfaceToImage();
      surfaceReady = true;
      await tester.pump();
    }
    await binding.takeScreenshot(name);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    // Long forms are lazy lists: scroll until the target is built.
    final lists = find.byType(Scrollable);
    if (finder.evaluate().isEmpty && lists.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(finder, 300, scrollable: lists.first);
    }
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  testWidgets('Every rider screen', (tester) async {
    final fakes = await pumpApp(tester);

    // Login (every login state is in integration_test/figma/onboarding_login_test.dart)
    await tap(tester, find.text('Sign in'));
    await tester.enterText(find.byKey(const Key('phoneField')), '9876543210');
    await settle(tester);
    await tap(tester, find.text('Send code'));
    for (final d in testOtp.split('')) {
      await tester.tap(
        find.descendant(of: find.byType(RiderKeypad), matching: find.text(d)),
      );
    }
    await settle(tester);
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Start shift'));

    // Register (every register state is in integration_test/figma/register_test.dart)
    expect(find.text('Tell us about you'), findsOneWidget);
    await shot(tester, '05_register');

    // Home (every Home, checklist and hub-trip state is in
    // integration_test/figma/home_test.dart)
    fakes.registration.application.value = fakes.riderApplication(
      RegistrationStatus.approved,
    );
    await settle(tester);
    expect(find.text('Stock not requested'), findsOneWidget);
    await shot(tester, '12_home');

    // The order screens are in integration_test/figma/order_test.dart.
    fakes.orders.history.value = [
      testOrder(
        status: OrderStatus.delivered,
        riderId: 'u1',
        pickedUpAt: DateTime.now().subtract(const Duration(seconds: 60)),
        deliveredAt: DateTime.now(),
      ),
    ];
    await settle(tester);

    // Profile, and logging out from it
    await tap(tester, find.byType(RiderAvatar));
    expect(find.text('Your profile'), findsOneWidget);
    await shot(tester, '19_profile');
    await tap(tester, find.text('Log out'));
    await shot(tester, '20_log_out');
    await tap(tester, find.text('Log out').last);
    expect(find.text('Deliver hot food in 90 seconds'), findsOneWidget);
    await shot(tester, '24_logged_out');
  });
}
