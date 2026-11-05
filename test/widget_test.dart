import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ninzo_rider/core/widgets/status_views.dart';
import 'package:ninzo_rider/core/widgets/rider/rider_ui.dart';
import 'package:ninzo_rider/features/auth/domain/entities/auth_failure.dart';
import 'package:ninzo_rider/features/auth/domain/entities/rider_account_info.dart';
import 'package:ninzo_rider/features/intro/domain/entities/app_permission.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_document.dart';

import 'fakes.dart';

void main() {
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> typeCode(WidgetTester tester, String code) async {
    for (final d in code.split('')) {
      await tester.tap(
        find.descendant(of: find.byType(RiderKeypad), matching: find.text(d)),
      );
    }
    await settle(tester);
  }

  testWidgets(
    'First launch: Welcome, the three permissions once, then the phone screen',
    (tester) async {
      final fakes = Fakes()..intro.seen = false;
      await pumpApp(tester, fakes);
      expect(find.text('Deliver hot food in 90 seconds'), findsOneWidget);

      await tap(tester, find.text('Sign in'));
      expect(find.text('PERMISSION 1 OF 3'), findsOneWidget);

      // Denying location shows "Location off" until it is allowed.
      fakes.permissions.denyRequests = true;
      await tap(tester, find.text('Allow location'));
      expect(find.text('Turn on location to go online'), findsOneWidget);
      await tap(tester, find.text('Open settings'));
      expect(fakes.permissions.opened, [AppPermission.location]);
      fakes.permissions.denyRequests = false;
      await tap(tester, find.text('I’ve turned it on'));

      expect(find.text('PERMISSION 2 OF 3'), findsOneWidget);
      await tap(tester, find.text('Not now'));
      expect(find.text('Allow camera access'), findsOneWidget);
      await tap(tester, find.text('Allow camera'));
      expect(find.text('Log in to start\nyour shift'), findsOneWidget);
      expect(fakes.intro.seen, isTrue);

      // Back goes to Welcome; signing in again skips the permissions.
      await tap(tester, find.bySemanticsLabel('Back'));
      await tap(tester, find.text('Sign in'));
      expect(find.text('Log in to start\nyour shift'), findsOneWidget);
    },
  );

  testWidgets(
    'Phone screen: invalid, not registered, no internet and on hold',
    (tester) async {
      final fakes = await pumpApp(tester);
      await tap(tester, find.text('Sign in'));

      await tester.enterText(find.byKey(const Key('phoneField')), '12345678');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(
        find.text(
          'Almost there! Enter all 10 digits, starting with 6, 7, 8 or 9.',
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('phoneField')), '9876543210');
      await settle(tester);
      expect(find.text('98765 43210'), findsOneWidget);

      fakes.directory.result = null;
      await tap(tester, find.text('Send code'));
      expect(find.textContaining('isn’t a rider account yet'), findsOneWidget);

      fakes.directory.failure = AuthFailureKind.noInternet;
      await tap(tester, find.text('Send code'));
      expect(find.textContaining('Waiting for internet'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      fakes.directory
        ..failure = null
        ..result = const RiderAccountInfo(onHold: true);
      await tap(tester, find.text('Try again'));
      expect(find.textContaining('Your account is on hold'), findsOneWidget);
      expect(find.text('Send code'), findsNothing);
    },
  );

  testWidgets(
    'Code screen: wrong code, expired, too many attempts, then verified and on to Register',
    (tester) async {
      final fakes = await pumpApp(tester);
      await tap(tester, find.text('Sign in'));
      await tester.enterText(find.byKey(const Key('phoneField')), '9876543210');
      await settle(tester);
      await tap(tester, find.text('Send code'));
      expect(find.text('We just sent an SMS'), findsOneWidget);
      expect(find.textContaining('Send again in 00:'), findsOneWidget);

      await typeCode(tester, '000000');
      await tap(tester, find.text('Continue'));
      expect(
        find.text('Almost there! Check the 6-digit code and enter it again.'),
        findsOneWidget,
      );

      fakes.auth.nextVerifyFailure = AuthFailureKind.codeExpired;
      await tap(tester, find.text('Continue'));
      expect(
        find.text('This code timed out. Tap Send again for a fresh one.'),
        findsOneWidget,
      );
      await tap(tester, find.text('Send again'));
      expect(find.textContaining('Send again in 00:'), findsOneWidget);

      await typeCode(tester, '111111');
      fakes.auth.nextVerifyFailure = AuthFailureKind.tooManyAttempts;
      await tap(tester, find.text('Continue'));
      expect(find.text('Try again in 30 minutes'), findsOneWidget);
      await tap(tester, find.text('Back to login'));
      await tap(tester, find.text('Send code'));

      await typeCode(tester, testOtp);
      await tap(tester, find.text('Continue'));
      expect(find.text('Verified!'), findsOneWidget);
      expect(
        find.text(
          'Your mobile number is verified. Your shift at Hub 2 · Yelahanka starts at 11:00 AM.',
        ),
        findsOneWidget,
      );
      expect(fakes.session.was, isTrue);

      await tap(tester, find.text('Start shift'));
      // Signed in without an application: Register, with the number filled in.
      expect(find.text('Tell us about you'), findsOneWidget);
      expect(find.text('98765 43210'), findsOneWidget);
    },
  );

  testWidgets('A session that ends on its own shows "Signed out"', (
    tester,
  ) async {
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    await pumpApp(tester, fakes);
    expect(find.text('Stock not requested'), findsOneWidget);

    fakes.auth.user.value = null; // e.g. signed in on another phone
    await settle(tester);
    expect(find.text('You’ve been signed out'), findsOneWidget);
    await tap(tester, find.text('Sign in'));
    expect(find.text('Log in to start\nyour shift'), findsOneWidget);
  });

  testWidgets(
    'Not keeping the rider signed in signs them out at the next start',
    (tester) async {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.session.keep = false;
      await pumpApp(tester, fakes);
      expect(find.text('You’ve been signed out'), findsOneWidget);
    },
  );

  testWidgets(
    'New rider: details, area, documents, review, approval, spot, Home',
    (tester) async {
      final fakes = await pumpApp(tester);
      await tap(tester, find.text('New rider? Register'));
      expect(find.text('Tell us about you'), findsOneWidget);
      expect(find.text('Step 1 of 3 · Details'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('nameField')), 'Ravi Kumar');
      await tester.enterText(find.byKey(const Key('phoneField')), '9876543210');
      await settle(tester);

      // Area search: popular areas, results, no results, pick.
      await tap(tester, find.byKey(const Key('areaField')));
      expect(find.text('Use my current location'), findsOneWidget);
      expect(find.text('Kogilu'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('areaSearch')), 'Yel');
      await settle(tester);
      expect(find.text('Yelahanka Satellite Town'), findsOneWidget);
      expect(find.text('Use my current location'), findsNothing);
      await tester.enterText(find.byKey(const Key('areaSearch')), 'Xyz');
      await settle(tester);
      expect(find.text('No area found'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('areaSearch')), 'Yel');
      await settle(tester);
      await tap(tester, find.text('Yelahanka'));
      expect(find.text('Tell us about you'), findsOneWidget);
      expect(find.text('Yelahanka'), findsOneWidget);

      // Already a rider: Register 03.
      await tap(tester, find.text('Continue'));
      expect(
        find.text('This number is already registered. Sign in instead.'),
        findsOneWidget,
      );

      // A new number: no code, straight to the documents.
      fakes.directory.result = null;
      await tap(tester, find.text('Continue'));
      expect(find.text('We just sent an SMS'), findsNothing);
      expect(find.text('Add your documents'), findsOneWidget);
      expect(find.text('0 of 5 added'), findsOneWidget);
      final saved = fakes.registration.application.value!;
      expect(saved.name, 'Ravi Kumar');
      expect(saved.area.name, 'Yelahanka');
      expect(saved.status, RegistrationStatus.draft);
      expect(fakes.registration.listed, ['+919876543210']);
      expect(fakes.users.user.value?.name, 'Ravi Kumar');

      // Aadhaar: front and back.
      await tap(tester, find.text('Add').first);
      expect(find.text('Aadhaar card · Front'), findsOneWidget);
      await tap(tester, find.text('Take photo'));
      expect(
        find.text('Can you read every line of text clearly?'),
        findsOneWidget,
      );
      await tap(tester, find.text('Use this photo'));
      expect(find.text('Aadhaar card · Back'), findsOneWidget);
      await tap(tester, find.text('Upload from gallery'));
      await tap(tester, find.text('Use this photo'));
      expect(find.text('1 of 5 added'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tap(tester, find.text('Add').first);
        await tap(tester, find.text('Take photo'));
        await tap(tester, find.text('Use this photo'));
      }
      expect(fakes.photos.taken.where((selfie) => selfie).length, 1);
      expect(find.text('5 of 5 added'), findsOneWidget);

      await tap(tester, find.text('Submit for review'));
      expect(find.text('Documents under review'), findsOneWidget);
      expect(find.textContaining('+91 98765 43210'), findsOneWidget);

    // "Done" keeps the rider here; the result shows up in place.
    await tap(tester, find.text('Done'));
    expect(find.text('Documents under review'), findsOneWidget);

      // The team asks for a retake.
      final reviewed = fakes.registration.application.value!;
      fakes.registration.application.value = reviewed.copyWith(
        status: RegistrationStatus.needsRetake,
        documents: {
          ...reviewed.documents,
          RiderDocument.drivingLicence: DocumentUpload(
            files: reviewed.documents[RiderDocument.drivingLicence]!.files,
            issue: DocumentIssue.retake,
          ),
        },
      );
      await settle(tester);
      expect(find.text('One document needs a retake'), findsOneWidget);
      await tap(tester, find.text('Retake driving licence'));
      expect(find.text('Driving licence · Front'), findsOneWidget);
      await tap(tester, find.text('Take photo'));
      await tap(tester, find.text('Use this photo'));
      expect(find.text('5 of 5 added'), findsOneWidget);
      await tap(tester, find.text('Submit for review'));
      expect(find.text('Documents under review'), findsOneWidget);

      // Approved: welcome, spot, Home.
      fakes.registration.application.value = fakes
          .riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar')
          .copyWith(welcomed: false);
      await settle(tester);
      expect(find.text('You’re approved, Ravi!'), findsOneWidget);
      await tap(tester, find.text('Sign in'));
      expect(find.text('You’ll ride from Yelahanka Node'), findsOneWidget);
      await tap(tester, find.text('Got it'));
      expect(find.text('Stock not requested'), findsOneWidget);
    },
  );

  testWidgets(
    'Every photo, from the camera or the gallery, is reviewed before it is used',
    (tester) async {
      final fakes = Fakes()..signIn(status: RegistrationStatus.draft);
      fakes.registration.application.value = fakes
          .riderApplication(RegistrationStatus.draft)
          .copyWith(documents: const {});
      await pumpApp(tester, fakes);
      expect(find.text('0 of 5 added'), findsOneWidget);
      Map<RiderDocument, DocumentUpload> saved() =>
          fakes.registration.application.value!.documents;

      // Register 05 → camera (the app goes to the background) → photo back.
      await tap(tester, find.text('Add').first);
      expect(find.text('Aadhaar card · Front'), findsOneWidget);
      final camera = fakes.photos.open = Completer<String?>();
      await tap(tester, find.text('Take photo'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      expect(find.text('Take photo'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      camera.complete('/photos/front.jpg');
      await settle(tester);

      // Register 06 shows and stays until the rider decides; nothing is uploaded.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(
        find.text('Can you read every line of text clearly?'),
        findsOneWidget,
      );
      expect(find.text('Aadhaar card · Front'), findsOneWidget);
      expect(find.text('Use this photo'), findsOneWidget);
      expect(saved(), isEmpty);

      // Retake → back to 05; a cancelled camera stays on 05.
      await tap(tester, find.text('Retake'));
      expect(find.text('Take photo'), findsOneWidget);
      final cancelled = fakes.photos.open = Completer<String?>();
      await tap(tester, find.text('Take photo'));
      cancelled.complete(null);
      await settle(tester);
      expect(find.text('Take photo'), findsOneWidget);
      expect(saved(), isEmpty);

      // Take it again, use it: on to the back.
      await tap(tester, find.text('Take photo'));
      expect(
        find.text('Can you read every line of text clearly?'),
        findsOneWidget,
      );
      await tap(tester, find.text('Use this photo'));
      expect(find.text('Aadhaar card · Back'), findsOneWidget);
      expect(find.text('Upload from gallery'), findsOneWidget);
      expect(saved()[RiderDocument.aadhaar]!.files.keys, [DocumentSide.front]);

      // The back from the gallery is reviewed too.
      final gallery = fakes.photos.open = Completer<String?>();
      await tap(tester, find.text('Upload from gallery'));
      gallery.complete('/photos/back.jpg');
      await settle(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Aadhaar card · Back'), findsOneWidget);
      expect(
        find.text('Can you read every line of text clearly?'),
        findsOneWidget,
      );
      expect(saved()[RiderDocument.aadhaar]!.files.keys, [DocumentSide.front]);
      await tap(tester, find.text('Use this photo'));
      expect(find.text('1 of 5 added'), findsOneWidget);
      expect(saved()[RiderDocument.aadhaar]!.files.keys, [
        DocumentSide.front,
        DocumentSide.back,
      ]);
    },
  );

  testWidgets('Failed and expired reviews reopen the documents', (
    tester,
  ) async {
    final fakes = Fakes()..signIn(status: RegistrationStatus.failed);
    final a = fakes.registration.application.value!;
    fakes.registration.application.value = a.copyWith(
      documents: {
        ...a.documents,
        RiderDocument.aadhaar: DocumentUpload(
          files: a.documents[RiderDocument.aadhaar]!.files,
          issue: DocumentIssue.nameMismatch,
        ),
        RiderDocument.drivingLicence: DocumentUpload(
          files: a.documents[RiderDocument.drivingLicence]!.files,
          issue: DocumentIssue.retake,
        ),
      },
    );
    await pumpApp(tester, fakes);
    expect(find.text('Let’s fix 2 details'), findsOneWidget);
    expect(
      find.text(
        'Your name and one photo need a quick update. Upload them again and we’ll check them.',
      ),
      findsOneWidget,
    );
    expect(find.text('Name needs matching'), findsOneWidget);
    await tap(tester, find.text('Upload documents by hand'));
    expect(find.text('3 of 5 added'), findsOneWidget);
    expect(
      fakes.registration.application.value!.status,
      RegistrationStatus.draft,
    );

    final b = fakes.registration.application.value!;
    fakes.registration.application.value = b.copyWith(
      status: RegistrationStatus.expired,
      documents: {
        for (final d in RiderDocument.values)
          d: DocumentUpload(
            files: b.documents[d]!.files,
            issue: d == RiderDocument.drivingLicence
                ? DocumentIssue.expired
                : null,
          ),
      },
    );
    await settle(tester);
    expect(find.text('Time to renew your driving licence'), findsOneWidget);
    await tap(tester, find.text('Update driving licence'));
    expect(find.text('4 of 5 added'), findsOneWidget);
  });

  testWidgets('Logout is blocked during a delivery, allowed otherwise', (
    tester,
  ) async {
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    await pumpApp(tester, fakes);

    await tester.tap(find.byType(RiderAvatar));
    await settle(tester);
    await tester.ensureVisible(find.text('Log out'));
    await settle(tester);
    await tester.tap(find.text('Log out'));
    await settle(tester);
    await tester.tap(find.text('Log out').last);
    await settle(tester);
    expect(find.text('Deliver hot food in 90 seconds'), findsOneWidget);
  });

  testWidgets('A load that failed tries again by itself, and stops when it is gone', (tester) async {
    var tries = 0;
    await tester.pumpWidget(MaterialApp(home: SilentRetry(onRetry: () => tries++)));
    await tester.pump(SilentRetry.every);
    expect(tries, 1);
    await tester.pump(SilentRetry.every);
    expect(tries, 2);
    await tester.pumpWidget(const MaterialApp(home: BlankScreen()));
    await tester.pump(SilentRetry.every);
    expect(tries, 2);
  });
}
