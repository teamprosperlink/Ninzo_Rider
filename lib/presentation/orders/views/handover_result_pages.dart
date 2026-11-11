import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/online_status.dart';
import '../../../domain/usecases/online_usecases.dart';
import '../../online/providers/online_providers.dart';
import '../../shift/providers/shift_providers.dart';
import '../../../domain/entities/delivery_order.dart';
import '../../../domain/usecases/handover_usecases.dart';
import '../viewmodels/handover_view_model.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../viewmodels/problem_report_view_model.dart';
import '../widgets/demo_order_controls.dart';
import 'order_result_pages.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

/// Handover 12: cash orders have no code. The rider handles change, so there's
/// no short-cash screen.
class CollectCashPage extends ConsumerWidget {
  const CollectCashPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OrderResultPage(
    title: AppStrings.collect(order.amount),
    body: AppStrings.cashOnDeliveryCollectTheFull,
    rows: [(AppStrings.order, AppStrings.hashNumber(order.number)), (AppStrings.payment, AppStrings.cash), (AppStrings.amount, AppStrings.rupeeAmount(order.amount))],
    action: AppStrings.iVeCollected(order.amount),
    busy: ref.watch(handoverViewModelProvider.select((s) => s.busy)),
    onAction: ref.read(handoverViewModelProvider.notifier).collected,
  );
}

/// Handover 13: the code doesn't work. No lockout and no wait: the rider checks
/// the customer's order screen and hands over.
class CheckDetailsPage extends ConsumerWidget {
  const CheckDetailsPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OrderResultPage(
    title: AppStrings.checkTheOrderDetails,
    body: AppStrings.askTheCustomerToOpenTheir,
    rows: [
      (AppStrings.orderNumber, AppStrings.hashNumber(order.number)),
      (AppStrings.items, plural(order.itemCount, AppStrings.item, AppStrings.items2)),
      (AppStrings.payment, AppStrings.paidByUpi),
    ],
    action: AppStrings.detailsMatchHandOver,
    busy: ref.watch(handoverViewModelProvider.select((s) => s.busy)),
    onAction: ref.read(handoverViewModelProvider.notifier).detailsMatch,
    secondary: AppStrings.detailsDonTMatch,
    onSecondary: () => ref.read(problemReportViewModelProvider.notifier).open(),
    extraBottom: AppSizes.s16,
  );
}

/// Handover 10: saved on the phone. Signal returning brings the rider on to the
/// next step; "Back to waiting" leaves it to sync by itself.
class HandoverSavedPage extends ConsumerWidget {
  const HandoverSavedPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(handoverViewModelProvider);
    final lastSync = state.local.lastSync ?? order.gateConfirmedAt;
    return OrderResultPage(
      title: AppStrings.handoverSaved,
      body: AppStrings.noSignalAtTheGateIt,
      rows: [
        (AppStrings.order, AppStrings.hashNumber(order.number)),
        (AppStrings.waitingToSync, plural(state.local.saved.length, AppStrings.event, AppStrings.events)),
        (AppStrings.lastSync, lastSync == null ? '' : lowerClockTime(lastSync)),
      ],
      action: AppStrings.backToWaiting,
      busy: state.busy,
      onAction: ref.read(handoverViewModelProvider.notifier).backToWaiting,
    );
  }
}

/// Handover 06, or 11 with another order waiting.
class OrderDeliveredPage extends ConsumerWidget {
  const OrderDeliveredPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(onlineStatusProvider).value ?? const OnlineStatus();
    final shift = ref.watch(todayShiftProvider).value;
    final busy = ref.watch(orderFlowViewModelProvider.select((s) => s.busy));
    final vm = ref.read(orderFlowViewModelProvider.notifier);
    final next = nextOrderOf(status, order.id);
    final time = clock(secondsToGateOf(order));
    final page = RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s52, AppSizes.s16, AppSizes.s16),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s24, AppSizes.s16, AppSizes.s12),
      bottom: [
        if (next == null)
          RiderButton(AppStrings.backToWaiting, onPressed: vm.backToSpot, loading: busy)
        else
          RiderButton(AppStrings.startNextOrder, onPressed: vm.startNext, loading: busy),
      ],
      children: [
        const Center(
          child: RiderTickHalo(outer: RiderColors.deliveredHaloOuter, inner: RiderColors.deliveredHaloInner),
        ),
        const SizedBox(height: AppSizes.s16),
        Text(AppStrings.deliveredIn(time), textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: AppSizes.s16),
        Text(
          next == null ? AppStrings.niceWorkTheCustomerHasTheir : AppStrings.niceWorkYourNextOrderIs,
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderSummaryCard(
          rows: [(AppStrings.order, AppStrings.hashNumber(order.number)), (AppStrings.timeToGate, time), (AppStrings.earned, AppStrings.rupeeAmount(order.riderFee))],
          valueColors: const {AppLimits.orderHighlightRow: RiderColors.brand},
        ),
        const SizedBox(height: AppSizes.s16),
        RiderSummaryCard(
          rows: [
            if (next == null)
              (AppStrings.itemsLeftOnScooter, '${shift == null ? 0 : scooterStockOf(shift, status).portionsLeft}')
            else
              (AppStrings.next(next.number, next.gate), plural(next.items, AppStrings.item, AppStrings.items2)),
          ],
        ),
      ],
    );
    if (!kDemoControls || next == null) return page;
    return Stack(
      fit: StackFit.expand,
      children: [
        page,
        Positioned(
          top: MediaQuery.viewPaddingOf(context).top + AppSizes.s12,
          right: AppSizes.s16,
          child: DemoDeliveredControls(orderId: order.id),
        ),
      ],
    );
  }
}
