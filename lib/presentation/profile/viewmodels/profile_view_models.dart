import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/demo_data.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/utils/time_format.dart';
import '../../account/viewmodels/account_view_model.dart';
import '../../auth/providers/auth_state_providers.dart';
import '../../orders/viewmodels/problem_report_view_model.dart';
import '../../register/providers/registration_provider.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/shift.dart';
import '../../../domain/entities/shift_push.dart';
import '../../shift/providers/shift_providers.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../../domain/entities/profile.dart';
import '../../../domain/usecases/profile_usecases.dart';
import '../providers/profile_providers.dart';
import '../../../core/constants/app_strings.dart';

/// Profile 01 and 07's header: name and "Rider · Hub 2 Yelahanka".
class ProfileHeaderData {
  const ProfileHeaderData({required this.name, required this.role});

  final String name;
  final String role;
}

final profileHeaderProvider = Provider.autoDispose<ProfileHeaderData>((ref) {
  final hub = ref.watch(todayShiftProvider).value?.hub;
  return ProfileHeaderData(
    name: ref.watch(registrationProvider).value?.name ?? '',
    role: hub == null ? '' : AppStrings.rider(hubLine(hub)),
  );
});

/// Profile 01 "Menu" and 03 "Log out confirm" (true while the sheet is up).
class ProfileMenuViewModel extends Notifier<bool> {
  @override
  bool build() => false;

  ShiftFlowViewModel get _flow => ref.read(shiftFlowViewModelProvider.notifier);

  void open(ShiftScreen screen) {
    // Help centre opens on FAQ, whatever it showed last.
    if (screen == ShiftScreen.profileHelp) ref.invalidate(helpCentreViewModelProvider);
    _flow.show(screen);
  }

  void back() => _flow.closeProfile();

  /// "Log out" → Profile 03.
  void askLogOut() => state = true;

  /// "Stay logged in" → Profile 01.
  void stayLoggedIn() => state = false;

  /// "Log out" on the sheet: the sign-out flow the app already had. No frame
  /// shows a failure; the sheet just closes.
  Future<void> logOut() async {
    await ref.read(accountViewModelProvider.notifier).signOut();
    if (ref.mounted) state = false;
  }

  /// Demo mode only: plays a push of Notification 01–04.
  Future<void> demoPush(ShiftPush push) async {
    final shift = ref.read(todayShiftProvider).value;
    if (shift == null) return;
    await ref.read(showPushUseCaseProvider)(
      push,
      shift,
      detail: const PushDetail(spotName: DemoData.nudgeSpotName, metersFromSpot: DemoData.riderAwayMeters),
    );
  }
}

final profileMenuViewModelProvider = NotifierProvider<ProfileMenuViewModel, bool>(ProfileMenuViewModel.new);

enum HelpTab { faq, contact }

/// Profile 02 (FAQ) and 09 (Contact us).
class HelpCentreViewModel extends Notifier<HelpTab> {
  @override
  HelpTab build() => HelpTab.faq;

  void show(HelpTab tab) => state = tab;

  void back() => ref.read(shiftFlowViewModelProvider.notifier).show(ShiftScreen.profile);

  /// "Report a problem" → Problem 01.
  void reportProblem() => ref.read(problemReportViewModelProvider.notifier).open();

  /// "Send feedback": true once the rider API has it.
  Future<bool> sendFeedback(String message) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return false;
    try {
      await ref.read(sendFeedbackUseCaseProvider)(uid, message);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final helpCentreViewModelProvider = NotifierProvider<HelpCentreViewModel, HelpTab>(HelpCentreViewModel.new);

/// Profile 04.
class MySpotState {
  const MySpotState({required this.spot, required this.hub, required this.distance, required this.assigned});

  final String spot;
  final String hub;
  final String distance;
  final String assigned;
}

class MySpotViewModel extends Notifier<MySpotState?> {
  /// "Navigate to spot": directions in Google Maps.
  Future<void> navigate() async {
    final spot = ref.read(todayShiftProvider).value?.spot;
    if (spot != null) await openDirections(spot.point);
  }

  @override
  MySpotState? build() {
    final shift = ref.watch(todayShiftProvider).value;
    if (shift == null) return null;
    final km = ref.watch(registrationProvider).value?.spotDistanceKm;
    final at = ref.watch(profileFactsProvider).value?.spotAssignedAt;
    return MySpotState(
      spot: shift.spot.name,
      hub: hubLine(shift.hub),
      distance: km == null ? '' : distance(km),
      assigned: at == null ? '' : whenLabel(at, ref.read(clockProvider)()),
    );
  }

  void back() => ref.read(shiftFlowViewModelProvider.notifier).show(ShiftScreen.profile);
}

final mySpotViewModelProvider = NotifierProvider.autoDispose<MySpotViewModel, MySpotState?>(MySpotViewModel.new);

/// A line of Profile 05.
typedef NotificationLine = ({String title, String when, String body});

class NotificationsViewModel extends Notifier<List<NotificationLine>> {
  @override
  List<NotificationLine> build() {
    final now = ref.read(clockProvider)();
    return [
      for (final RiderNotification n in ref.watch(riderNotificationsProvider).value ?? const [])
        (title: n.title, when: whenLabel(n.at, now), body: n.body),
    ];
  }

  void back() => ref.read(shiftFlowViewModelProvider.notifier).show(ShiftScreen.profile);
}

final notificationsViewModelProvider = NotifierProvider.autoDispose<NotificationsViewModel, List<NotificationLine>>(
  NotificationsViewModel.new,
);

/// A line of Profile 06.
typedef ShiftLine = ({String day, String detail, String earned});

class MyShiftsViewModel extends Notifier<List<ShiftLine>> {
  @override
  List<ShiftLine> build() {
    final now = ref.read(clockProvider)();
    final records = ref.watch(shiftRecordsProvider).value ?? const <ShiftRecord>[];
    return [
      for (final record in shiftsInLastSevenDays(records, now))
        (
          day: shiftDayLabel(record.date, now),
          detail: AppStrings.dotPair(plural(record.orders, AppStrings.order3, AppStrings.orders2), hoursAndMinutes(onlineTimeOf(record, now))),
          earned: rupees(record.earned),
        ),
    ];
  }

  void back() => ref.read(shiftFlowViewModelProvider.notifier).show(ShiftScreen.profile);
}

final myShiftsViewModelProvider = NotifierProvider.autoDispose<MyShiftsViewModel, List<ShiftLine>>(MyShiftsViewModel.new);

/// Profile 07's rows.
class YourProfileViewModel extends Notifier<List<(String, String)>> {
  @override
  List<(String, String)> build() {
    final rider = ref.watch(registrationProvider).value;
    final Shift? shift = ref.watch(todayShiftProvider).value;
    final since = ref.watch(profileFactsProvider).value?.riderSince;
    return [
      (AppStrings.name, rider?.name ?? ''),
      (AppStrings.mobile, rider == null ? '' : maskedMobile(rider.phone)),
      (AppStrings.hub, shift == null ? '' : hubLine(shift.hub)),
      (AppStrings.spot, shift?.spot.name ?? ''),
      (AppStrings.riderSince, since == null ? '' : monthYear(since)),
    ];
  }

  void back() => ref.read(shiftFlowViewModelProvider.notifier).show(ShiftScreen.profile);
}

final yourProfileViewModelProvider = NotifierProvider.autoDispose<YourProfileViewModel, List<(String, String)>>(
  YourProfileViewModel.new,
);

/// Profile 08.
class DocumentsViewModel extends Notifier<List<ProfileDocument>> {
  @override
  List<ProfileDocument> build() => profileDocumentsOf(ref.watch(registrationProvider).value);

  void back() => ref.read(shiftFlowViewModelProvider.notifier).show(ShiftScreen.profile);
}

final documentsViewModelProvider = NotifierProvider.autoDispose<DocumentsViewModel, List<ProfileDocument>>(
  DocumentsViewModel.new,
);
