import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/status_views.dart';
import '../../online/viewmodels/choose_spot_view_model.dart';
import '../../online/viewmodels/go_online_view_model.dart';
import '../../online/viewmodels/online_map_view_model.dart';
import '../../../domain/entities/online_status.dart';
import '../../online/providers/online_providers.dart';
import '../../orders/providers/order_providers.dart';
import '../../refill/viewmodels/refill_view_model.dart';
import '../../stock/viewmodels/stock_flow_view_model.dart';
import '../../../domain/entities/restock.dart';
import '../../../domain/entities/shift_end.dart';
import '../../shift_end/viewmodels/end_shift_view_model.dart';
import '../../shift_end/viewmodels/shift_issue_view_model.dart';
import '../../orders/viewmodels/problem_report_view_model.dart';
import '../../profile/viewmodels/profile_view_models.dart';
import '../providers/shift_providers.dart';
import '../viewmodels/shift_flow_view_model.dart';
import '../../../routing/app_router.dart';

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
    if (activeOrderId != null) return activeOrderPage();

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
            if (shift == null) {
              return noShiftPage(
                flow.screen,
                reporting: ref.watch(problemReportViewModelProvider.select((s) => s.open)),
              );
            }
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
              child: shiftScreenPage(
                screen,
                ref,
                shift: shift,
                status: status,
                scannedHere: scannedHere,
                stayedOnline: flow.stayedOnline,
              ),
            );
          },
        );
  }
}
