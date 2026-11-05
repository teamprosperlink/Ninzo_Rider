import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/widgets/status_views.dart';
import '../../../online/presentation/viewmodels/choose_spot_view_model.dart';
import '../../../online/presentation/viewmodels/go_online_view_model.dart';
import '../../../online/presentation/viewmodels/online_map_view_model.dart';
import '../../../online/domain/entities/online_status.dart';
import '../../../online/presentation/views/add_time_page.dart';
import '../../../online/presentation/views/break_pages.dart';
import '../../../online/presentation/views/choose_spot_page.dart';
import '../../../online/presentation/views/go_online_page.dart';
import '../../../online/presentation/views/online_map_page.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../online/presentation/widgets/demo_choose_spot_pill.dart';
import '../../../orders/presentation/providers/order_providers.dart';
import '../../../orders/presentation/views/order_flow_page.dart';
import '../../../refill/domain/usecases/refill_usecases.dart';
import '../../../refill/presentation/viewmodels/refill_view_model.dart';
import '../../../refill/presentation/views/refill_pages.dart';
import '../../../refill/presentation/views/restock_page.dart';
import '../../../stock/presentation/viewmodels/stock_flow_view_model.dart';
import '../../../stock/presentation/views/stock_confirmed_page.dart';
import '../../../stock/presentation/views/stock_flow_page.dart';
import '../../../stock/presentation/views/stock_list_page.dart';
import '../../../refill/domain/entities/restock.dart';
import '../../../shift_end/domain/entities/shift_end.dart';
import '../../../shift_end/presentation/viewmodels/end_shift_view_model.dart';
import '../../../shift_end/presentation/viewmodels/shift_issue_view_model.dart';
import '../../../shift_end/presentation/views/earnings_sync_pages.dart';
import '../../../shift_end/presentation/views/end_shift_page.dart';
import '../../../shift_end/presentation/views/shift_issue_page.dart';
import '../../../shift_end/presentation/views/shift_summary_page.dart';
import '../../../shift_end/presentation/widgets/demo_shift_end_pills.dart';
import '../../../orders/presentation/viewmodels/problem_report_view_model.dart';
import '../../../orders/presentation/views/problem_report_page.dart';
import '../../../profile/presentation/viewmodels/profile_view_models.dart';
import '../../../profile/presentation/views/help_centre_page.dart';
import '../../../profile/presentation/views/profile_detail_pages.dart';
import '../../../profile/presentation/views/profile_menu_page.dart';
import '../../domain/entities/shift.dart';
import '../providers/shift_providers.dart';
import '../viewmodels/shift_flow_view_model.dart';
import 'checklist_page.dart';
import 'home_page.dart';
import 'hub_map_page.dart';
import 'hub_status_page.dart';
import 'stock_empty_page.dart';

/// The approved rider's root screen: their day, from Home through the
/// checklist and the hub trip (Figma Sections 4–7). Later sections plug in
/// through [ShiftScreen] and the shift's phase.
class ShiftFlowView extends ConsumerWidget {
  const ShiftFlowView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    ref.watch(handoverSyncProvider);

    // Start order (Shift 28): the order takes over the screen until it's done.
    final activeOrderId = ref.watch(onlineStatusProvider.select((s) => s.value?.activeOrderId));
    if (activeOrderId != null) return const OrderFlowPage();

    final vm = ref.read(shiftFlowViewModelProvider.notifier);
    final flow = ref.watch(shiftFlowViewModelProvider);
    final status = ref.watch(onlineStatusProvider).value ?? const OnlineStatus();
    // Scans wait on the phone without signal; Home counts them too (Shift 08).
    final scannedHere = ref.watch(stockFlowViewModelProvider.select((s) => s.tally?.portionsLoaded));
    return ref
        .watch(todayShiftProvider)
        .when(
          // A failure after the shift has loaded keeps the screen as it is.
          skipError: true,
          loading: () => const BlankScreen(),
          error: (_, _) => SilentRetry(onRetry: () => ref.invalidate(todayShiftProvider)),
          data: (shift) {
            if (shift == null) return const NoShiftHomePage();
            final screen = vm.screenFor(shift, status);
            return PopScope(
              canPop: screen == ShiftScreen.home,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                switch (screen) {
                  case ShiftScreen.stockScan:
                    ref.read(stockFlowViewModelProvider.notifier).back();
                  case ShiftScreen.goOnline:
                    ref.read(goOnlineViewModelProvider.notifier).back();
                  case ShiftScreen.chooseSpot:
                    ref.read(chooseSpotViewModelProvider.notifier).back();
                  // The main map stays until the rider goes offline.
                  case ShiftScreen.online:
                  // Nothing in the design leads off these but their buttons.
                  case ShiftScreen.onBreak:
                  case ShiftScreen.refillAlert:
                  case ShiftScreen.refilled:
                  case ShiftScreen.shiftSummary:
                    break;
                  case ShiftScreen.shiftIssue:
                    final issue = ref.read(shiftIssueViewModelProvider);
                    if (issue == ShiftIssue.shiftAlreadyOpen || issue == ShiftIssue.noInternet) vm.home();
                  case ShiftScreen.atHub:
                    ref.read(refillViewModelProvider.notifier).leaveHub();
                  case ShiftScreen.restock:
                    final refill = ref.read(refillViewModelProvider.notifier);
                    if (ref.read(refillViewModelProvider).editing != null) {
                      refill.cancelEdit();
                    } else if (status.restock?.stage == RestockStage.suggested) {
                      refill.dismissRestock();
                    } else {
                      refill.backToMap();
                    }
                  case ShiftScreen.addTime:
                    ref.read(onlineMapViewModelProvider.notifier).letShiftEnd();
                  case ShiftScreen.endShift:
                    if (ref.read(endShiftViewModelProvider).stage != EndShiftStage.ending) vm.show(null);
                  case ShiftScreen.viewStock:
                  case ShiftScreen.takeBreak:
                  case ShiftScreen.earnings:
                  case ShiftScreen.syncStatus:
                    vm.show(null);
                  case ShiftScreen.profile:
                    final menu = ref.read(profileMenuViewModelProvider.notifier);
                    ref.read(profileMenuViewModelProvider) ? menu.stayLoggedIn() : menu.back();
                  case ShiftScreen.profileHelp:
                    final report = ref.read(problemReportViewModelProvider.notifier);
                    ref.read(problemReportViewModelProvider).open ? report.close() : vm.show(ShiftScreen.profile);
                  case ShiftScreen.profileSpot:
                  case ShiftScreen.profileNotifications:
                  case ShiftScreen.profileShifts:
                  case ShiftScreen.profileDetails:
                  case ShiftScreen.profileDocuments:
                    vm.show(ShiftScreen.profile);
                  default:
                    vm.home();
                }
              },
              child: switch (screen) {
                ShiftScreen.home => Stack(
                  children: [
                    HomePage(
                      shift: shift.phase == ShiftPhase.scanning && scannedHere != null
                          ? shift.copyWith(stock: shift.stock.copyWith(scanned: scannedHere))
                          : shift,
                    ),
                    if (kDemoMode && shift.phase == ShiftPhase.notStarted) const DemoStartPill(),
                    if (kDemoMode && shift.phase == ShiftPhase.stockLoaded) const DemoChooseSpotPill(),
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
                ShiftScreen.profileSpot => const MySpotPage(),
                ShiftScreen.profileNotifications => const NotificationsPage(),
                ShiftScreen.profileShifts => const MyShiftsPage(),
                ShiftScreen.profileDetails => const YourProfilePage(),
                ShiftScreen.profileDocuments => const DocumentsPage(),
                ShiftScreen.refillAlert => RefillAlertPage(
                  shift: shift,
                  status: status,
                  prompt: refillPromptOf(shift, status, stayedOnline: flow.stayedOnline),
                ),
                ShiftScreen.refilled => const RefilledPage(),
                ShiftScreen.restock => RestockPage(request: status.restock!),
              },
            );
          },
        );
  }
}
