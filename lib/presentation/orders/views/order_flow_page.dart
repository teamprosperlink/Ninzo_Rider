import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/status_views.dart';
import '../../../domain/entities/delivery_order.dart';
import '../viewmodels/handover_view_model.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../viewmodels/problem_report_view_model.dart';
import 'gate_page.dart';
import 'handover_page.dart';
import 'handover_result_pages.dart';
import 'order_map_page.dart';
import 'problem_report_page.dart';
import 'skip_order_page.dart';
import '../../../routing/app_router.dart';

/// A started order, from assignment to delivery. Figma's frames are states of
/// these screens:
///
/// * [OrderMapPage]: Order 01–03, Navigate 01–03
/// * [SkipOrderPage]: Order 04
/// * [GatePage]: Arrival 01, 02, 04
/// * the result: Order 05, Arrival 03, Navigate 04–06
/// * [HandoverPage]: Handover 01–05, 07–10, 12, 13
/// * [OrderDeliveredPage]: Handover 06, 11
/// * [ProblemReportPage]: Problem 01–03, over any of the above
class OrderFlowPage extends ConsumerWidget {
  const OrderFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(orderFlowViewModelProvider.select((s) => s.step));
    final vm = ref.read(orderFlowViewModelProvider.notifier);
    final reporting = ref.watch(problemReportViewModelProvider.select((s) => s.open));
    return ref
        .watch(activeOrderProvider)
        .when(
          // A failure after the order has loaded keeps the screen as it is.
          skipError: true,
          loading: () => const BlankScreen(),
          error: (_, _) => SilentRetry(onRetry: () => ref.invalidate(activeOrderProvider)),
          data: (order) {
            if (order == null) return const BlankScreen();
            final stillOn = order.status == DeliveryStatus.onTheWay || order.status == DeliveryStatus.atGate;
            final Widget page = orderPage(order, step, reporting: reporting && stillOn);
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                if (reporting && stillOn) {
                  ref.read(problemReportViewModelProvider.notifier).close();
                  return;
                }
                switch ((order.status, step)) {
                  case (DeliveryStatus.assigned, OrderStep.skip):
                    vm.keepOrder();
                  case (DeliveryStatus.onTheWay, OrderStep.gate):
                    vm.backFromGate();
                  case (DeliveryStatus.atGate, OrderStep.handover):
                    if (!ref.read(handoverViewModelProvider.notifier).back()) {
                      // Saved on the phone: "Back to waiting" is the way out.
                      if (ref.read(handoverViewModelProvider).step == HandoverStep.pack) vm.backToGateConfirmed();
                    }
                  // The order stays until it's done; no way back from the rest.
                  default:
                    break;
                }
              },
              child: page,
            );
          },
        );
  }
}
