import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_mode.dart';
import '../domain/entities/delivery_order.dart';
import '../domain/entities/online_status.dart';
import '../domain/entities/rider_application.dart';
import '../domain/entities/shift.dart';
import '../domain/entities/shift_end.dart';
import '../domain/usecases/refill_usecases.dart';
import '../presentation/auth/viewmodels/login_view_model.dart';
import '../presentation/auth/views/login_view.dart';
import '../presentation/intro/views/permission_view.dart';
import '../presentation/intro/views/signed_out_view.dart';
import '../presentation/intro/views/splash_view.dart';
import '../presentation/intro/views/welcome_view.dart';
import '../presentation/online/views/add_time_page.dart';
import '../presentation/online/views/break_pages.dart';
import '../presentation/online/views/choose_spot_page.dart';
import '../presentation/online/views/go_online_page.dart';
import '../presentation/online/views/online_map_page.dart';
import '../presentation/online/widgets/demo_choose_spot_pill.dart';
import '../presentation/orders/viewmodels/handover_view_model.dart';
import '../presentation/orders/viewmodels/order_flow_view_model.dart';
import '../presentation/orders/viewmodels/problem_report_view_model.dart';
import '../presentation/orders/views/gate_page.dart';
import '../presentation/orders/views/handover_page.dart';
import '../presentation/orders/views/handover_result_pages.dart';
import '../presentation/orders/views/order_flow_page.dart';
import '../presentation/orders/views/order_map_page.dart';
import '../presentation/orders/views/order_result_pages.dart';
import '../presentation/orders/views/problem_report_page.dart';
import '../presentation/orders/views/skip_order_page.dart';
import '../presentation/profile/views/help_centre_page.dart';
import '../presentation/profile/views/profile_detail_pages.dart' as profile;
import '../presentation/profile/views/profile_menu_page.dart';
import '../presentation/refill/views/refill_pages.dart';
import '../presentation/refill/views/restock_page.dart';
import '../presentation/register/viewmodels/register_view_model.dart';
import '../presentation/register/views/area_page.dart';
import '../presentation/register/views/details_page.dart';
import '../presentation/register/views/documents_page.dart' as register;
import '../presentation/register/views/photo_pages.dart';
import '../presentation/register/views/register_view.dart';
import '../presentation/register/views/status_pages.dart';
import '../presentation/shift/viewmodels/shift_flow_view_model.dart';
import '../presentation/shift/views/checklist_page.dart';
import '../presentation/shift/views/home_page.dart';
import '../presentation/shift/views/hub_map_page.dart';
import '../presentation/shift/views/hub_status_page.dart';
import '../presentation/shift/views/shift_flow_view.dart';
import '../presentation/shift/views/stock_empty_page.dart';
import '../presentation/shift_end/viewmodels/shift_issue_view_model.dart';
import '../presentation/shift_end/views/earnings_sync_pages.dart';
import '../presentation/shift_end/views/end_shift_page.dart';
import '../presentation/shift_end/views/shift_issue_page.dart';
import '../presentation/shift_end/views/shift_summary_page.dart';
import '../presentation/shift_end/widgets/demo_shift_end_pills.dart';
import '../presentation/stock/viewmodels/stock_flow_view_model.dart';
import '../presentation/stock/views/lot_alert_page.dart';
import '../presentation/stock/views/manual_count_page.dart';
import '../presentation/stock/views/scan_stock_page.dart';
import '../presentation/stock/views/scans_saved_page.dart';
import '../presentation/stock/views/stock_confirmed_page.dart';
import '../presentation/stock/views/stock_flow_page.dart';
import '../presentation/stock/views/stock_list_page.dart';
import '../presentation/auth/providers/auth_state_providers.dart';
import '../presentation/intro/viewmodels/intro_flow_view_model.dart';
import '../presentation/register/providers/registration_provider.dart';

/// Which root screen shows.
enum AppStage {
  /// Onboard 01, while the session is restored.
  splash,

  /// Onboard 02.
  welcome,

  /// Onboard 03–06.
  permissions,

  /// Login 01–16.
  login,

  /// Onboard 07.
  signedOut,

  /// Register 01–16: new rider details (signed out), then, once the number
  /// is verified, documents, review and approval until the rider has seen
  /// their spot.
  register,

  /// The rider's day (Shift 01–12, 51–53): Home, the pre-shift checklist
  /// and the hub trip; later sections continue from there.
  home,
}

/// Which root screen to show.
final appStageProvider = Provider<AsyncValue<AppStage>>((ref) {
  final startup = ref.watch(appStartupProvider);
  if (startup.hasError) return AsyncError(startup.error!, startup.stackTrace!);
  if (!startup.hasValue) return const AsyncData(AppStage.splash);

  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return AsyncError(auth.error!, auth.stackTrace!);
  if (!auth.hasValue) return const AsyncData(AppStage.splash);

  if (auth.value == null) {
    return AsyncData(switch (ref.watch(introFlowProvider).screen) {
      IntroScreen.welcome => AppStage.welcome,
      IntroScreen.permission => AppStage.permissions,
      IntroScreen.login => AppStage.login,
      IntroScreen.signedOut => AppStage.signedOut,
      IntroScreen.register => AppStage.register,
    });
  }
  // "Verified!" stays up until the rider taps Start shift.
  if (ref.watch(loginHoldProvider)) return const AsyncData(AppStage.login);

  final application = ref.watch(registrationProvider);
  return application.whenData((a) => a != null && a.isActive ? AppStage.home : AppStage.register);
});

/// Re-subscribes to the session after a load error.
void retrySession(WidgetRef ref) => ref
  ..invalidate(appStartupProvider)
  ..invalidate(authStateProvider)
  ..invalidate(registrationProvider);

// ── Every screen in the app: which enum value opens which page ──
// Which screen follows which (the Figma tap map, 231 taps): docs/flow_map.md.

/// The root screen for each [AppStage].
Widget appStagePage(AppStage stage, IntroFlowViewModel flow) => switch (stage) {
  AppStage.splash => const SplashView(),
  AppStage.welcome => WelcomeView(onSignIn: flow.signIn, onRegister: flow.register),
  AppStage.permissions => const PermissionView(),
  AppStage.login => LoginView(onBack: flow.backToWelcome, onRegister: flow.register),
  AppStage.signedOut => SignedOutView(onSignIn: flow.signIn),
  AppStage.register => RegisterView(onBack: flow.backToWelcome, onSignIn: flow.signIn),
  AppStage.home => const ShiftFlowView(),
};

/// Login 01–16.
Widget loginStepPage(
  LoginStep step,
  WidgetRef ref, {
  required LoginProvider provider,
  required VoidCallback onBack,
  required VoidCallback onRegister,
}) => switch (step) {
  LoginStep.phone => PhoneStep(provider: provider, onBack: onBack, onRegister: onRegister),
  LoginStep.code => CodeStep(provider: provider),
  LoginStep.paused => LoginPausedPage(
    onBackToLogin: ref.read(provider.notifier).editNumber,
    minutes: ref.watch(provider.select((s) => s.pausedMinutes)),
  ),
};

/// Register 01–16.
Widget registerScreenPage(
  RegisterScreen screen,
  RiderApplication? application, {
  required VoidCallback onBack,
  required VoidCallback onSignIn,
  required VoidCallback onContinue,
}) => switch (screen) {
  RegisterScreen.details => DetailsPage(onBack: onBack, onSignIn: onSignIn, onContinue: onContinue),
  RegisterScreen.area => const AreaPage(),
  RegisterScreen.documents => register.DocumentsPage(application: application!),
  RegisterScreen.photo => const PhotoPage(),
  RegisterScreen.review => const PhotoReviewPage(),
  RegisterScreen.status => StatusPage(application: application!),
};

/// The rider has no shift today: Home, or Profile opened from its avatar.
Widget noShiftPage(ShiftScreen? screen, {required bool reporting}) => switch (screen) {
  ShiftScreen.profile => const ProfileMenuPage(shift: null),
  ShiftScreen.profileHelp => reporting ? const ProblemReportPage() : const HelpCentrePage(shift: null),
  ShiftScreen.profileSpot => const profile.MySpotPage(),
  ShiftScreen.profileNotifications => const profile.NotificationsPage(),
  ShiftScreen.profileShifts => const profile.MyShiftsPage(),
  ShiftScreen.profileDetails => const profile.YourProfilePage(),
  ShiftScreen.profileDocuments => const profile.DocumentsPage(),
  _ => const NoShiftHomePage(),
};

/// A started order takes over from every [ShiftScreen].
Widget activeOrderPage() => const OrderFlowPage();

/// The rider's day, for each [ShiftScreen].
Widget shiftScreenPage(
  ShiftScreen screen,
  WidgetRef ref, {
  required Shift shift,
  required OnlineStatus status,
  required int? scannedHere,
  required bool stayedOnline,
}) {
  final vm = ref.read(shiftFlowViewModelProvider.notifier);
  return switch (screen) {
    ShiftScreen.home => Stack(
      children: [
        HomePage(
          shift: shift.phase == ShiftPhase.scanning && scannedHere != null
              ? shift.copyWith(stock: shift.stock.copyWith(scanned: scannedHere))
              : shift,
        ),
        if (kDemoControls && shift.phase == ShiftPhase.notStarted) const DemoStartPill(),
        if (kDemoControls && shift.phase == ShiftPhase.stockLoaded) const DemoChooseSpotPill(),
      ],
    ),
    ShiftScreen.checklist => ChecklistPage(shift: shift),
    ShiftScreen.hubMap => HubMapPage(shift: shift),
    ShiftScreen.hubStatus => HubStatusPage(shift: shift),
    ShiftScreen.stockEmpty => StockEmptyPage(shift: shift),
    ShiftScreen.atHub => RefillAtHubPage(shift: shift),
    ShiftScreen.stockScan => const StockFlowPage(),
    ShiftScreen.stockConfirmed => const StockConfirmedPage(),
    ShiftScreen.chooseSpot => const ChooseSpotPage(),
    ShiftScreen.goOnline => GoOnlinePage(shift: shift),
    ShiftScreen.online => OnlineMapPage(shift: shift),
    ShiftScreen.addTime => const AddTimePage(),
    ShiftScreen.viewStock => StockListPage(onBack: () => vm.show(null)),
    ShiftScreen.takeBreak => const TakeBreakPage(),
    ShiftScreen.onBreak => OnBreakPage(state: status.breakState!),
    ShiftScreen.endShift => EndShiftPage(shift: shift),
    ShiftScreen.shiftSummary => ShiftSummaryPage(shift: shift),
    ShiftScreen.shiftIssue => ShiftIssuePage(
      issue: ref.watch(shiftIssueViewModelProvider) ?? ShiftIssue.noInternet,
    ),
    ShiftScreen.earnings => const EarningsPage(),
    ShiftScreen.syncStatus => const SyncStatusPage(),
    ShiftScreen.profile => ProfileMenuPage(shift: shift),
    ShiftScreen.profileHelp =>
      ref.watch(problemReportViewModelProvider.select((s) => s.open))
          ? const ProblemReportPage()
          : HelpCentrePage(shift: shift),
    ShiftScreen.profileSpot => const profile.MySpotPage(),
    ShiftScreen.profileNotifications => const profile.NotificationsPage(),
    ShiftScreen.profileShifts => const profile.MyShiftsPage(),
    ShiftScreen.profileDetails => const profile.YourProfilePage(),
    ShiftScreen.profileDocuments => const profile.DocumentsPage(),
    ShiftScreen.refillAlert => RefillAlertPage(
      shift: shift,
      status: status,
      prompt: refillPromptOf(shift, status, stayedOnline: stayedOnline),
    ),
    ShiftScreen.refilled => const RefilledPage(),
    ShiftScreen.restock => RestockPage(request: status.restock!),
  };
}

/// Stock 01–: scanning stock onto the scooter.
Widget stockScreenPage(StockScreen screen) => switch (screen) {
  StockScreen.scan => const ScanStockPage(),
  StockScreen.list => const StockListPage(),
  StockScreen.manual => const ManualCountPage(),
  StockScreen.saved => const ScansSavedPage(),
  StockScreen.lotAlert => const LotAlertPage(),
};

/// A started order, from assignment to delivery. [reporting] puts the problem
/// report over it.
Widget orderPage(DeliveryOrder order, OrderStep step, {required bool reporting}) => reporting
    ? const ProblemReportPage()
    : switch (order.status) {
        DeliveryStatus.assigned when step == OrderStep.skip => SkipOrderPage(order: order),
        // The rider API packs before the ride (Handover 01 from Order 01).
        DeliveryStatus.assigned when step == OrderStep.handover => HandoverPage(order: order),
        DeliveryStatus.assigned => OrderMapPage(order: order),
        DeliveryStatus.onTheWay when step == OrderStep.gate => GatePage(order: order),
        // The rider API has no gate scan: the code comes next.
        DeliveryStatus.onTheWay when step == OrderStep.handover => HandoverPage(order: order),
        DeliveryStatus.onTheWay => OrderMapPage(order: order),
        // The rider API skips Arrival 03 too.
        DeliveryStatus.atGate when step == OrderStep.handover || kRiderApi => HandoverPage(order: order),
        DeliveryStatus.atGate => GateConfirmedPage(order: order),
        DeliveryStatus.skipped => OrderSkippedPage(order: order),
        DeliveryStatus.cancelled => OrderCancelledPage(order: order),
        DeliveryStatus.delivered => OrderDeliveredPage(order: order),
      };

/// An order at the gate, for each [HandoverStep].
Widget handoverStepPage(HandoverStep step, DeliveryOrder order) => switch (step) {
  HandoverStep.pack => PackPage(order: order),
  HandoverStep.quantity => CheckItemsPage(order: order),
  HandoverStep.code => const CustomerCodePage(),
  HandoverStep.waiting => CustomerWaitingPage(order: order),
  HandoverStep.details => CheckDetailsPage(order: order),
  HandoverStep.cash => CollectCashPage(order: order),
  HandoverStep.saved => HandoverSavedPage(order: order),
};
