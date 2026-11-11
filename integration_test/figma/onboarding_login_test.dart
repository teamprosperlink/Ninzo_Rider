import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ninzo_rider/core/widgets/rider/rider_ui.dart';
import 'package:ninzo_rider/domain/entities/app_user.dart';
import 'package:ninzo_rider/domain/entities/auth_failure.dart';
import 'package:ninzo_rider/domain/entities/rider_account_info.dart';
import 'package:ninzo_rider/domain/entities/rider_application.dart';

import '../../test/fakes.dart';

/// Figma Section 1 (Onboarding, 7 frames) and Section 2 (Login, 16 frames):
/// drives every state on a device against fake repositories and saves a
/// screenshot named after each Figma frame, to compare with the design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/onboarding_login_test.dart -d emulator-5554
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

  Future<void> type(WidgetTester tester, String digits) async {
    await tester.tap(find.byKey(const Key('phoneField')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('phoneField')), digits);
    await settle(tester);
  }

  Future<void> keys(WidgetTester tester, String digits) async {
    for (final d in digits.split('')) {
      await tester.tap(
        find.descendant(of: find.byType(RiderKeypad), matching: find.text(d)),
      );
      await tester.pump();
    }
    await settle(tester);
  }

  Future<void> delete(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pump();
    }
    await settle(tester);
  }

  void unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  testWidgets('Onboarding and Login match Figma', (tester) async {
    // Lay out at the Figma frame size, 360 × 800 with a 48px status bar, so
    // each screenshot lines up with its frame.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 144, bottom: 48)
      ..viewPadding = const FakeViewPadding(top: 144, bottom: 48);
    addTearDown(tester.view.reset);

    final fakes = Fakes()
      ..intro.seen = false
      ..splash = const Duration(seconds: 8)
      ..permissions.denyRequests = true;
    // A rider with a profile, so "Start shift" leads home.
    fakes.users.user.value = const AppUser(
      uid: 'u1',
      phone: '+919876543210',
      name: 'Ravi',
    );
    fakes.registration.application.value = fakes.riderApplication(
      RegistrationStatus.approved,
    );
    await pumpApp(tester, fakes);

    // ── Section 1 · Onboarding ──
    expect(find.text('HOT FOOD. 90 SECONDS.'), findsOneWidget);
    await shot(tester, 'onboard_01_splash');
    await tester.pump(const Duration(seconds: 8));
    await settle(tester);

    expect(find.text('Deliver hot food in 90 seconds'), findsOneWidget);
    await shot(tester, 'onboard_02_welcome');

    await tap(tester, find.text('Sign in'));
    expect(find.text('PERMISSION 1 OF 3'), findsOneWidget);
    await shot(tester, 'onboard_03_location_permission');

    await tap(tester, find.text('Allow location')); // denied
    expect(find.text('Turn on location to go online'), findsOneWidget);
    await shot(tester, 'onboard_06_location_off');

    fakes.permissions.denyRequests = false;
    await tap(tester, find.text('I’ve turned it on'));
    expect(find.text('PERMISSION 2 OF 3'), findsOneWidget);
    await shot(tester, 'onboard_04_notifications_permission');

    await tap(tester, find.text('Turn on notifications').last);
    expect(find.text('PERMISSION 3 OF 3'), findsOneWidget);
    await shot(tester, 'onboard_05_camera_permission');

    await tap(tester, find.text('Allow camera'));

    // ── Section 2 · Login: phone screen ──
    expect(find.text('Log in to start\nyour shift'), findsOneWidget);
    await shot(tester, 'login_01_phone_empty');

    await type(tester, '987654');
    // The design draws these frames without the keyboard; the field keeps its focus.
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    await shot(tester, 'login_13_typing_number');

    await type(tester, '12345678');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    unfocus();
    expect(
      find.text(
        'Almost there! Enter all 10 digits, starting with 6, 7, 8 or 9.',
      ),
      findsOneWidget,
    );
    await shot(tester, 'login_14_invalid_number');

    await type(tester, '9876543210');
    unfocus();
    await shot(tester, 'login_02_phone_valid');

    fakes.directory.result = null;
    await tap(tester, find.text('Send code'));
    expect(find.textContaining('isn’t a rider account yet'), findsOneWidget);
    await shot(tester, 'login_03_not_registered');

    fakes.directory.failure = AuthFailureKind.noInternet;
    await tap(tester, find.text('Send code'));
    expect(find.text('Try again'), findsOneWidget);
    await shot(tester, 'login_12_no_internet');

    fakes.directory
      ..failure = null
      ..result = const RiderAccountInfo(onHold: true);
    await tap(tester, find.text('Try again'));
    expect(find.textContaining('Your account is on hold'), findsOneWidget);
    await shot(tester, 'login_16_account_on_hold');

    fakes.directory.result = const RiderAccountInfo(
      hubLabel: 'Hub 2 · Yelahanka',
      shiftStart: '11:00 AM',
    );
    await type(tester, '987654321');
    await type(tester, '9876543210');
    unfocus();
    final sending = fakes.auth.sendGate = Completer<void>();
    await tap(tester, find.text('Send code'));
    expect(find.text('Sending code…'), findsOneWidget);
    await shot(tester, 'login_15_sending_code');
    sending.complete();
    await settle(tester);

    // ── Code screen ──
    expect(find.text('We just sent an SMS'), findsOneWidget);
    await shot(tester, 'login_04_code_empty');

    await keys(tester, '482');
    await shot(tester, 'login_05_code_typing');

    await keys(tester, '916');
    await tap(tester, find.text('Continue'));
    expect(
      find.text('Almost there! Check the 6-digit code and enter it again.'),
      findsOneWidget,
    );
    await shot(tester, 'login_06_wrong_code');

    await delete(tester, 1);
    await keys(tester, '5');
    final verifying = fakes.auth.verifyGate = Completer<void>();
    await tap(tester, find.text('Continue'));
    expect(find.text('Verifying…'), findsOneWidget);
    await shot(tester, 'login_07_verifying');
    verifying.complete();
    await settle(tester);

    await delete(tester, 1);
    await keys(tester, '6');
    fakes.auth.nextVerifyFailure = AuthFailureKind.codeExpired;
    await tap(tester, find.text('Continue'));
    expect(
      find.text('This code timed out. Tap Send again for a fresh one.'),
      findsOneWidget,
    );
    await shot(tester, 'login_11_code_expired');

    await tap(tester, find.text('Send again'));
    await keys(tester, '111111');
    fakes.auth.nextVerifyFailure = AuthFailureKind.tooManyAttempts;
    await tap(tester, find.text('Continue'));
    expect(find.text('Try again in 30 minutes'), findsOneWidget);
    await shot(tester, 'login_10_too_many_attempts');

    await tap(tester, find.text('Back to login'));
    unfocus();
    await tap(tester, find.text('Send code'));
    await keys(tester, '482');
    fakes.clockOffset += const Duration(seconds: 31);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Send again'), findsOneWidget);
    await shot(tester, 'login_08_resend_available');

    await delete(tester, 3);
    await keys(tester, testOtp);
    await tap(tester, find.text('Continue'));
    expect(find.text('Verified!'), findsOneWidget);
    await shot(tester, 'login_09_verified');

    await tap(tester, find.text('Start shift'));
    expect(find.text('Verified!'), findsNothing);

    // The session ends on its own (e.g. signed in on another phone).
    fakes.auth.user.value = null;
    await settle(tester);
    expect(find.text('You’ve been signed out'), findsOneWidget);
    await shot(tester, 'onboard_07_signed_out');

    await tap(tester, find.text('Sign in'));
    expect(find.text('Log in to start\nyour shift'), findsOneWidget);
  });
}
