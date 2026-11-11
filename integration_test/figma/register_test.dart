import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ninzo_rider/domain/entities/rider_application.dart';
import 'package:ninzo_rider/domain/entities/rider_document.dart';

import '../../test/fakes.dart';

/// Figma Section 3 (Register, 16 frames): drives every state on a device
/// against fake repositories and saves a screenshot named after each Figma
/// frame, to compare with the design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/register_test.dart -d emulator-5554
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

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
    await tester.enterText(find.byKey(Key(key)), text);
    await settle(tester);
  }

  void unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  testWidgets('Register matches Figma', (tester) async {
    // Lay out at the Figma frame size, 360 × 800 with a 48px status bar.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 144, bottom: 48)
      ..viewPadding = const FakeViewPadding(top: 144, bottom: 48);
    addTearDown(tester.view.reset);

    final fakes = await pumpApp(tester);
    final registration = fakes.registration;

    await tap(tester, find.text('New rider? Register'));

    // ── Details ──
    await tester.tap(find.byKey(const Key('nameField')));
    await settle(tester);
    expect(find.text('Tell us about you'), findsOneWidget);
    // The design draws these frames without the keyboard; the field keeps its focus.
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    await shot(tester, 'register_01_details_empty');

    await type(tester, 'nameField', 'Ravi Kumar');
    await type(tester, 'phoneField', '9876543210');
    unfocus();

    // ── Your area ──
    await tap(tester, find.byKey(const Key('areaField')));
    unfocus();
    expect(find.text('Use my current location'), findsOneWidget);
    await shot(tester, 'register_14_search_your_area');

    await type(tester, 'areaSearch', 'Yel');
    unfocus();
    expect(find.text('Yelahanka Satellite Town'), findsOneWidget);
    await shot(tester, 'register_15_search_results');

    await type(tester, 'areaSearch', 'Xyz');
    unfocus();
    expect(find.text('No area found'), findsOneWidget);
    await shot(tester, 'register_16_search_no_results');

    await type(tester, 'areaSearch', 'Yel');
    unfocus();
    await tap(tester, find.text('Yelahanka'));
    expect(find.text('Tell us about you'), findsOneWidget);
    await shot(tester, 'register_02_details_filled');

    await tap(tester, find.text('Continue'));
    expect(
      find.text('This number is already registered. Sign in instead.'),
      findsOneWidget,
    );
    await shot(tester, 'register_03_number_already_registered');

    // ── A new number: no code, straight to the documents ──
    fakes.directory.result = null;
    await tap(tester, find.text('Continue'));

    // ── Documents ──
    expect(find.text('0 of 5 added'), findsOneWidget);
    await shot(tester, 'register_04_documents_none_added');

    await tap(tester, find.text('Add').first);
    expect(find.text('Aadhaar card · Front'), findsOneWidget);
    await shot(tester, 'register_05_take_photo');

    await tap(tester, find.text('Take photo'));
    expect(find.text('PHOTO PREVIEW'), findsOneWidget);
    await shot(tester, 'register_06_photo_review');

    await tap(tester, find.text('Use this photo'));
    await tap(tester, find.text('Take photo'));
    await tap(tester, find.text('Use this photo'));
    for (var i = 0; i < 4; i++) {
      await tap(tester, find.text('Add').first);
      await tap(tester, find.text('Take photo'));
      await tap(tester, find.text('Use this photo'));
    }
    expect(find.text('5 of 5 added'), findsOneWidget);
    await shot(tester, 'register_07_documents_complete');

    // ── Review ──
    await tap(tester, find.text('Submit for review'));
    final now = DateTime.now();
    final submitted = registration.application.value!.copyWith(
      submittedAt: DateTime(now.year, now.month, now.day, 14, 14),
    );
    registration.application.value = submitted;
    await settle(tester);
    expect(find.text('Documents under review'), findsOneWidget);
    await shot(tester, 'register_08_under_review');

    RiderApplication flagged(
      RegistrationStatus status,
      Map<RiderDocument, DocumentIssue> issues,
    ) => submitted.copyWith(
      status: status,
      documents: {
        for (final d in RiderDocument.values)
          d: DocumentUpload(
            files: submitted.documents[d]!.files,
            issue: issues[d],
          ),
      },
    );

    registration.application.value = flagged(RegistrationStatus.needsRetake, {
      RiderDocument.drivingLicence: DocumentIssue.retake,
    });
    await settle(tester);
    expect(find.text('One document needs a retake'), findsOneWidget);
    await shot(tester, 'register_11_needs_a_retake');

    registration.application.value = flagged(RegistrationStatus.failed, {
      RiderDocument.aadhaar: DocumentIssue.nameMismatch,
      RiderDocument.drivingLicence: DocumentIssue.retake,
    });
    await settle(tester);
    expect(find.text('Let’s fix 2 details'), findsOneWidget);
    await shot(tester, 'register_12_verification_failed');

    registration.application.value = flagged(RegistrationStatus.expired, {
      RiderDocument.drivingLicence: DocumentIssue.expired,
    });
    await settle(tester);
    expect(find.text('Time to renew your driving licence'), findsOneWidget);
    await shot(tester, 'register_13_verification_expired');

    // ── Approved ──
    final approved = fakes.riderApplication(
      RegistrationStatus.approved,
      name: 'Ravi Kumar',
    );
    registration.application.value = approved.copyWith(welcomed: false);
    await settle(tester);
    expect(find.text('You’re approved, Ravi!'), findsOneWidget);
    await shot(tester, 'register_09_approved');

    await tap(tester, find.text('Sign in'));
    expect(find.text('You’ll ride from Yelahanka Node'), findsOneWidget);
    await shot(tester, 'register_10_spot_assigned');

    await tap(tester, find.text('Got it'));
    expect(registration.application.value!.welcomed, isTrue);
  });
}
