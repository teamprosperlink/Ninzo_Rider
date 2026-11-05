import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:ninzo_rider/app/app.dart';
import 'package:ninzo_rider/core/widgets/rider/rider_status.dart';
import 'package:ninzo_rider/features/online/domain/entities/online_status.dart';
import 'package:ninzo_rider/features/online/domain/usecases/plan_online_pushes.dart';
import 'package:ninzo_rider/features/profile/domain/entities/profile.dart';
import 'package:ninzo_rider/features/profile/domain/usecases/profile_usecases.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_application.dart';
import 'package:ninzo_rider/features/register/domain/entities/rider_document.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift.dart';
import 'package:ninzo_rider/features/shift/domain/entities/shift_push.dart';
import 'package:ninzo_rider/features/shift/presentation/viewmodels/shift_flow_view_model.dart';

import 'fakes.dart';

void main() {
  final now = DateTime(2026, 11, 3, 9, 41);

  group('Profile rules', () {
    test('the mobile is masked as Profile 07 draws it', () {
      expect(maskedMobile('+919876543210'), '+91 98•••• ••210');
      expect(maskedMobile('12345'), '12345');
    });

    test('when: today with the time, yesterday, then the weekday', () {
      expect(whenLabel(DateTime(2026, 11, 3, 9, 12), now), 'Today, 9:12 AM');
      expect(whenLabel(DateTime(2026, 11, 2, 22), now), 'Yesterday');
      expect(whenLabel(DateTime(2026, 10, 26, 9), now), 'Mon');
    });

    test('shift days and time online', () {
      expect(shiftDayLabel(DateTime(2026, 11, 3), now), 'Today');
      expect(shiftDayLabel(DateTime(2026, 11, 2), now), 'Mon, 2 Nov');
      final running = ShiftRecord(
        date: DateTime(2026, 11, 3),
        orders: 1,
        earned: 40,
        onlineAt: DateTime(2026, 11, 3, 9),
        plannedEnd: DateTime(2026, 11, 3, 13),
      );
      expect(onlineTimeOf(running, now), const Duration(minutes: 41));
      final forgotten = ShiftRecord(
        date: DateTime(2026, 11, 2),
        orders: 1,
        earned: 40,
        onlineAt: DateTime(2026, 11, 2, 9),
        plannedEnd: DateTime(2026, 11, 2, 13),
      );
      expect(onlineTimeOf(forgotten, now), const Duration(hours: 4));
    });

    test('last 7 days: today and the six before, only shifts the rider rode', () {
      ShiftRecord on(DateTime date, {bool rode = true}) => ShiftRecord(
        date: date,
        orders: 0,
        earned: 0,
        onlineAt: rode ? date : null,
        plannedEnd: date,
      );
      final kept = shiftsInLastSevenDays([
        on(DateTime(2026, 11, 3)),
        on(DateTime(2026, 11, 2), rode: false),
        on(DateTime(2026, 10, 28)),
        on(DateTime(2026, 10, 27)),
      ], now);
      expect(kept.map((r) => r.date), [DateTime(2026, 11, 3), DateTime(2026, 10, 28)]);
    });

    test('documents: the three of the frame, verified once approved', () {
      expect(profileDocumentsOf(null).map((d) => d.label), ['Driving licence', 'ID proof', 'Selfie']);
      expect(profileDocumentsOf(null).any((d) => d.verified), isFalse);
      final approved = Fakes().riderApplication(RegistrationStatus.approved);
      expect(profileDocumentsOf(approved).every((d) => d.verified), isTrue);
      final flagged = RiderApplication(
        uid: 'u1',
        name: 'Ravi',
        phone: '+919876543210',
        area: approved.area,
        status: RegistrationStatus.approved,
        documents: {RiderDocument.selfie: DocumentUpload(issue: DocumentIssue.values.first)},
      );
      expect(profileDocumentsOf(flagged).last.verified, isFalse);
    });
  });

  group('Notification 01–04 plan', () {
    const plan = PlanOnlinePushes();
    final online = testShift(phase: ShiftPhase.online);
    const nudge = RelocationNudge(
      spot: Spot(name: 'Jakkur Node', point: LatLng(13.1, 77.6)),
      ordersWaiting: 3,
      meters: 800,
      rideMinutes: 5,
    );

    test('shift ending is scheduled 15 minutes before the end while online', () {
      final current = online.end.subtract(const Duration(hours: 1));
      final result = plan(online, const OnlineStatus(), current);
      expect(result.schedule[ShiftPush.shiftEndingSoon], online.end.subtract(const Duration(minutes: 15)));
      final moved = online.end.add(const Duration(hours: 1));
      expect(
        plan(online, OnlineStatus(shiftEnd: moved), current).schedule[ShiftPush.shiftEndingSoon],
        moved.subtract(const Duration(minutes: 15)),
      );
      expect(plan(testShift(), const OnlineStatus(), current).cancel, {ShiftPush.shiftEndingSoon});
    });

    test('orders waiting comes once, when the nudge arrives', () {
      const status = OnlineStatus(nudge: nudge);
      final first = plan(online, status, now, previous: const OnlineStatus());
      expect(first.showNow, {ShiftPush.ordersWaiting});
      expect(first.detail.spotName, 'Jakkur Node');
      expect(plan(online, status, now, previous: status).showNow, isEmpty);
    });

    test('spot assigned comes when the system changes the spot, not on taking a nudge', () {
      final moved = online.copyWith(spot: const Spot(name: 'Jakkur Node', point: LatLng(13.1, 77.6)));
      expect(plan(moved, const OnlineStatus(), now, previousShift: online).showNow, {ShiftPush.spotAssigned});
      expect(
        plan(moved, const OnlineStatus(nudge: nudge), now, previousShift: online).showNow,
        isNot(contains(ShiftPush.spotAssigned)),
      );
    });

    test('away comes when the rider leaves the spot, once', () {
      final left = plan.onPosition(online, const OnlineStatus(), 30, 180);
      expect(left.showNow, {ShiftPush.awayFromSpot});
      expect(left.detail.metersFromSpot, 180);
      expect(plan.onPosition(online, const OnlineStatus(), 180, 190).showNow, isEmpty);
      expect(plan.onPosition(testShift(), const OnlineStatus(), 30, 180).showNow, isEmpty);
    });

    test('the text is as in the frames', () {
      final shift = testShift();
      expect(ShiftPushContent.of(ShiftPush.spotAssigned, shift).title, 'Your spot is Yelahanka Node');
      expect(ShiftPushContent.of(ShiftPush.shiftEndingSoon, shift).title, 'Your shift ends in 15 minutes');
      expect(
        ShiftPushContent.of(ShiftPush.ordersWaiting, shift, detail: const PushDetail(spotName: 'Jakkur Node')).title,
        'Orders are waiting at Jakkur Node',
      );
      expect(
        ShiftPushContent.of(ShiftPush.awayFromSpot, shift, detail: const PushDetail(metersFromSpot: 180)).body,
        'You’re 180 m from Yelahanka Node. Head back to keep getting orders.',
      );
      expect(ShiftPush.spotAssigned.hasActions, isFalse);
      expect(ShiftPush.reminder.hasActions, isTrue);
    });
  });

  group('Profile screens', () {
    Fakes rider({ShiftPhase phase = ShiftPhase.notStarted}) {
      final fakes = Fakes()..signIn(status: RegistrationStatus.approved);
      fakes.registration.application.value = fakes.riderApplication(RegistrationStatus.approved, name: 'Ravi Kumar');
      fakes.shifts.shift.value = testShift(stockRequest: StockRequestStatus.ready, phase: phase);
      return fakes;
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      await tester.tap(find.text(text).last);
      await settle(tester);
    }

    void tall(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(1440, 2400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> back(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
    }

    testWidgets('the avatar opens Profile 01; every drawn arrow leads on; back returns to Home', (tester) async {
      tall(tester);
      final fakes = rider();
      fakes.profile.facts.value = ProfileFacts(riderSince: DateTime(2026, 10), spotAssignedAt: DateTime(2026, 1, 1));
      await pumpApp(tester, fakes);

      await tester.tap(find.byType(RiderAvatar));
      await settle(tester);
      expect(find.text('Rider · Hub 2 Yelahanka'), findsOneWidget);

      await tapText(tester, 'My spot · Yelahanka Node');
      expect(find.text('Navigate to spot'), findsOneWidget);
      expect(find.text('1.2 km'), findsOneWidget);
      await back(tester);

      await tapText(tester, 'Notifications');
      expect(find.text('Notifications'), findsOneWidget);
      await back(tester);

      await tapText(tester, 'My shifts');
      expect(find.text('Last 7 days'), findsOneWidget);
      await back(tester);

      await tapText(tester, 'Your profile');
      expect(find.text('Oct 2026'), findsOneWidget);
      expect(find.text('+91 98•••• ••210'), findsOneWidget);
      await back(tester);

      await tapText(tester, 'Documents');
      expect(find.text('Verified'), findsNWidgets(3));
      await back(tester);

      await back(tester);
      expect(find.text('Your ride'), findsOneWidget);
    });

    testWidgets('Help centre: Contact us, Report a problem goes to the report and back', (tester) async {
      tall(tester);
      final fakes = rider();
      await pumpApp(tester, fakes);
      await tester.tap(find.byType(RiderAvatar));
      await settle(tester);
      await tapText(tester, 'Help centre');
      expect(find.text('How do I go online?'), findsOneWidget);

      await tapText(tester, 'Contact us');
      await tapText(tester, 'Report a problem');
      expect(find.text('Send report'), findsOneWidget);
      await tapText(tester, 'Breakdown');
      await tapText(tester, 'Send report');
      expect(find.text('Report sent'), findsOneWidget);
      expect(fakes.problemReports.sent.single.orderId, isNull);

      await tapText(tester, 'Back to order');
      expect(find.text('Hub manager'), findsOneWidget);
    });

    testWidgets('things with no arrow do nothing', (tester) async {
      tall(tester);
      await pumpApp(tester, rider());
      await tester.tap(find.byType(RiderAvatar));
      await settle(tester);
      await tapText(tester, 'Privacy policy');
      expect(find.text('Your profile'), findsOneWidget);

      await tapText(tester, 'My shifts');
      await tapText(tester, 'Earlier');
      expect(find.text('Last 7 days'), findsOneWidget);
    });

    testWidgets('empty lists draw no card, and add no text', (tester) async {
      tall(tester);
      await pumpApp(tester, rider());
      await tester.tap(find.byType(RiderAvatar));
      await settle(tester);
      await tapText(tester, 'Notifications');
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('log out asks first and uses the sign-out flow', (tester) async {
      tall(tester);
      await pumpApp(tester, rider());
      await tester.tap(find.byType(RiderAvatar));
      await settle(tester);

      await tapText(tester, 'Log out');
      expect(find.text('You’ll need your mobile number and a code to log back in.'), findsOneWidget);
      await tapText(tester, 'Stay logged in');
      expect(find.text('Your profile'), findsOneWidget);

      await tapText(tester, 'Log out');
      await tapText(tester, 'Log out');
      expect(find.text('Deliver hot food in 90 seconds'), findsOneWidget);
    });

    testWidgets('a tapped push leads where the flow map draws it', (tester) async {
      tall(tester);
      final fakes = rider();
      await pumpApp(tester, fakes);

      fakes.notifier.open(ShiftPush.spotAssigned);
      await settle(tester);
      expect(find.text('Navigate to spot'), findsOneWidget);
      await back(tester);
      expect(find.text('Your profile'), findsOneWidget);
      await back(tester);

      final container = ProviderScope.containerOf(tester.element(find.byType(NinzoRiderApp)));
      container.read(shiftFlowViewModelProvider.notifier).show(ShiftScreen.profile);
      await settle(tester);
      fakes.notifier.open(ShiftPush.ordersWaiting);
      await settle(tester);
      expect(find.text('Your ride'), findsOneWidget);
    });

    testWidgets('a nudge shows Notification 03 from the running app', (tester) async {
      tall(tester);
      final fakes = rider(phase: ShiftPhase.online);
      await pumpApp(tester, fakes);
      fakes.online.status.value = const OnlineStatus(
        nudge: RelocationNudge(
          spot: Spot(name: 'Jakkur Node', point: LatLng(13.1, 77.6)),
          ordersWaiting: 3,
          meters: 800,
          rideMinutes: 5,
        ),
      );
      await settle(tester);
      expect(fakes.notifier.shown, contains(ShiftPush.ordersWaiting));
      expect(fakes.notifier.shownDetail[ShiftPush.ordersWaiting]?.spotName, 'Jakkur Node');
    });
  });
}
