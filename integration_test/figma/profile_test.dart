import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ninzo_rider/app/app.dart';
import 'package:ninzo_rider/core/design/rider_tokens.dart';
import 'package:ninzo_rider/core/widgets/rider/rider_status.dart';
import 'package:ninzo_rider/features/online/domain/entities/online_status.dart';
import 'package:ninzo_rider/features/profile/domain/entities/profile.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift_push.dart';
import 'package:ninzo_rider/features/shift/presentation/viewmodels/shift_flow_view_model.dart';
import 'package:ninzo_rider/features/shift/presentation/widgets/push_preview.dart';

import '../../test/fakes.dart';

/// Figma Sections 25 and 26 (Profile 01–09, Notification 01–04; 13 frames):
/// drives every state on a device against fake repositories, and saves a
/// screenshot named after each Figma frame, to compare with the design.
///
/// ```
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/figma/profile_test.dart -d emulator-5554
/// ```
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceReady = false;

  Future<void> wait(WidgetTester tester, int ms) async {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 700));
    await wait(tester, 800);
    if (Platform.isAndroid && !surfaceReady) {
      await binding.convertFlutterSurfaceToImage();
      surfaceReady = true;
      await tester.pump();
    }
    await binding.takeScreenshot(name);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
    await wait(tester, 100);
  }

  void frameSize(WidgetTester tester) {
    surfaceReady = false;
    // Lay out at the Figma frame size, 360 × 800 with a 48px status bar.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 144, bottom: 48)
      ..viewPadding = const FakeViewPadding(top: 144, bottom: 48);
    addTearDown(tester.view.reset);
  }

  // The frames' day: Tuesday, 3 November, 9:41.
  final frameNow = DateTime(2026, 11, 3, 9, 41);

  Fakes rider({ShiftPhase phase = ShiftPhase.notStarted}) {
    final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
    fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
    fakes.now = frameNow;
    fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: phase);
    fakes.online.status.value = const OnlineStatus();
    fakes.profile.facts.value = ProfileFacts(
      riderSince: DateTime(2026, 10),
      spotAssignedAt: DateTime(2026, 11, 3, 9, 12),
    );
    fakes.profile.notifications.value = [
      RiderNotification(
        id: '0',
        title: 'Spot assigned · Yelahanka Node',
        body: 'Head there when you’re ready to ride.',
        at: DateTime(2026, 11, 3, 9, 12),
      ),
      RiderNotification(
        id: '1',
        title: 'Welcome to Ninzo',
        body: 'Your account is approved. Finish the pre-shift checks to start.',
        at: DateTime(2026, 11, 2, 9),
      ),
      RiderNotification(
        id: '2',
        title: 'Orders waiting at Jakkur Node',
        body: 'Your ride there is paid time. Orders reach you when you arrive.',
        at: DateTime(2026, 10, 26, 9),
      ),
    ];
    ShiftRecord record(int day, int month, int orders, int minutes, double earned) {
      final date = DateTime(2026, month, day);
      return ShiftRecord(
        date: date,
        orders: orders,
        earned: earned,
        onlineAt: date,
        plannedEnd: date.add(const Duration(hours: 23)),
        endedAt: date.add(Duration(minutes: minutes)),
      );
    }

    fakes.profile.shifts.value = [
      record(3, 11, 9, 252, 360),
      record(2, 11, 11, 340, 445),
      record(1, 11, 8, 245, 330),
      record(31, 10, 12, 370, 470),
    ];
    return fakes;
  }

  testWidgets('Profile 01–09: the menu and where it leads', (tester) async {
    frameSize(tester);
    await pumpApp(tester, rider());
    await wait(tester, 200);

    await tester.tap(find.byType(RiderAvatar));
    await settle(tester);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    await shot(tester, 'profile_01_menu');

    await tap(tester, 'Help centre');
    expect(find.text('How do I go online?'), findsOneWidget);
    await shot(tester, 'profile_02_help_centre');
    await tap(tester, 'Contact us');
    expect(find.text('Report a problem'), findsOneWidget);
    await shot(tester, 'profile_09_help_centre_contact_us');
    await tap(tester, 'Report a problem');
    expect(find.text('Send report'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.text('Hub manager'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    await tap(tester, 'My spot · Yelahanka Node');
    expect(find.text('Today, 9:12 AM'), findsOneWidget);
    await shot(tester, 'profile_04_my_spot');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    await tap(tester, 'Notifications');
    expect(find.text('Yesterday'), findsOneWidget);
    await shot(tester, 'profile_05_notifications');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    await tap(tester, 'My shifts');
    expect(find.text('9 orders · 4h 12m'), findsOneWidget);
    await shot(tester, 'profile_06_my_shifts');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    await tap(tester, 'Your profile');
    expect(find.text('+91 98•••• ••210'), findsOneWidget);
    await shot(tester, 'profile_07_your_profile');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);

    await tap(tester, 'Documents');
    expect(find.text('Verified'), findsNWidgets(3));
    await shot(tester, 'profile_08_documents');
  });

  testWidgets('Profile 03: log out, over an online rider as the frame has it', (tester) async {
    frameSize(tester);
    // The frame's chip says Online.
    await pumpApp(tester, rider(phase: ShiftPhase.online));
    await wait(tester, 200);
    ProviderScope.containerOf(tester.element(find.byType(NinzoRiderApp)))
        .read(shiftFlowViewModelProvider.notifier)
        .openProfile();
    await settle(tester);
    await tap(tester, 'Log out');
    expect(find.text('Stay logged in'), findsOneWidget);
    await shot(tester, 'profile_03_log_out_confirm');
    await tap(tester, 'Stay logged in');
    expect(find.text('Your profile'), findsOneWidget);
  });

  testWidgets('Notification 01–04', (tester) async {
    frameSize(tester);
    for (final (push, name, detail) in const [
      (ShiftPush.spotAssigned, 'notification_01_spot_assigned_push', PushDetail()),
      (ShiftPush.shiftEndingSoon, 'notification_02_shift_ending_soon_push', PushDetail()),
      (ShiftPush.ordersWaiting, 'notification_03_orders_waiting_push', PushDetail(spotName: 'Jakkur Node')),
      (ShiftPush.awayFromSpot, 'notification_04_away_from_spot_push', PushDetail(metersFromSpot: 180)),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(scaffoldBackgroundColor: RiderColors.screen),
          home: ShiftPushPreview(push: push, shift: testShift(), now: frameNow, detail: detail),
        ),
      );
      expect(find.text(ShiftPushContent.of(push, testShift(), detail: detail).title), findsOneWidget);
      await shot(tester, name);
    }
  });
}
