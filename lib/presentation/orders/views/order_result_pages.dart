import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/delivery_order.dart';
import '../../../domain/usecases/delivery_usecases.dart';
import '../viewmodels/handover_view_model.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// A tick, a heading, a line, a summary and a button or two: Order 05, Arrival
/// 03, Navigate 04–06, Handover 10, 12, 13, Problem 03.
class OrderResultPage extends StatelessWidget {
  const OrderResultPage({
    super.key,
    required this.title,
    required this.body,
    required this.rows,
    required this.action,
    required this.onAction,
    this.busy = false,
    this.secondary,
    this.onSecondary,
    this.extraBottom = AppSizes.s0,
  });

  final String title;
  final String body;
  final List<(String, String)> rows;
  final String action;
  final VoidCallback onAction;
  final bool busy;

  /// A second, grey button.
  final String? secondary;
  final VoidCallback? onSecondary;

  /// More room under the buttons.
  final double extraBottom;

  @override
  Widget build(BuildContext context) => RiderScaffold(
    showBack: false,
    bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s48, AppSizes.s16, AppSizes.s16),
    bottomToEdge: true,
    bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
    bottomPadding: EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s12, AppSizes.s16, AppSizes.s24 + extraBottom),
    bottom: [
      RiderButton(action, onPressed: onAction, loading: busy),
      if (secondary != null) RiderButton.ghost(secondary!, onPressed: onSecondary),
    ],
    children: [
      const Center(child: RiderTickHalo.small()),
      const SizedBox(height: AppSizes.s12),
      Text(title, textAlign: TextAlign.center, style: RiderText.h4),
      const SizedBox(height: AppSizes.s12),
      Text(
        body,
        textAlign: TextAlign.center,
        style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
      ),
      if (rows.isNotEmpty) ...[
        const SizedBox(height: AppSizes.s60),
        RiderSummaryCard(rows: rows, divided: false, radius: RiderRadius.field),
      ],
    ],
  );
}

/// Order 05: back to the spot → Shift 26.
class OrderSkippedPage extends ConsumerWidget {
  const OrderSkippedPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OrderResultPage(
    title: AppStrings.orderSkipped,
    body: AppStrings.weVePassedItToThe,
    rows: [
      (AppStrings.order, AppStrings.hashNumber(order.number)),
      (AppStrings.status, AppStrings.reassigned),
      (AppStrings.reason, order.skipReason?.label ?? ''),
    ],
    action: AppStrings.backToYourSpot,
    busy: ref.watch(orderFlowViewModelProvider.select((s) => s.busy)),
    onAction: ref.read(orderFlowViewModelProvider.notifier).backToSpot,
  );
}

/// Navigate 04–06, by how the cancellation pays: back to the spot → Shift 26,
/// or Shift 28 with the next order in the queue. The food stays on the scooter.
class OrderCancelledPage extends ConsumerWidget {
  const OrderCancelledPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pay = cancellationPayOf(order);
    final (body, rows) = switch (pay.kind) {
      CancellationKind.upiFlat => (
        AppStrings.theCustomerCancelledThisOrderYou(pay.tripPay),
        [(AppStrings.orderValue, AppStrings.rupeeAmount(order.amount)), (AppStrings.status, AppStrings.cancelled), (AppStrings.tripPay, AppStrings.rupeeAmount(pay.tripPay))],
      ),
      CancellationKind.cash => (
        AppStrings.theCustomerCancelledThisCashOrder,
        [(AppStrings.order, AppStrings.hashNumber(order.number)), (AppStrings.status, AppStrings.cancelled), (AppStrings.payment, order.payment.label)],
      ),
      // Navigate 06 as drawn; the cap is the rider API's (`cancel_pay_cap`), the pay the earnings'.
      CancellationKind.upiFull => (
        AppStrings.theCustomerCancelledThisOrderIt(OrderRules.cancelPayCap),
        [(AppStrings.orderValue, AppStrings.rupeeAmount(order.amount)), (AppStrings.status, AppStrings.cancelled), (AppStrings.tripPay, AppStrings.rupeeAmount(pay.tripPay))],
      ),
    };
    return OrderResultPage(
      title: AppStrings.orderCancelled,
      body: body,
      rows: rows,
      action: AppStrings.backToYourSpot,
      busy: ref.watch(orderFlowViewModelProvider.select((s) => s.busy)),
      onAction: ref.read(orderFlowViewModelProvider.notifier).backToSpot,
    );
  }
}

/// Arrival 03: "Hand over order" → Handover 01.
class GateConfirmedPage extends ConsumerWidget {
  const GateConfirmedPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(orderFlowViewModelProvider.select((s) => s.position));
    final meters = me == null ? null : const Distance().as(LengthUnit.Meter, me, order.gate.point).round();
    return OrderResultPage(
      title: AppStrings.confirmed(order.gate.name),
      body: AppStrings.youReAtTheGateHand,
      rows: [
        (AppStrings.order, AppStrings.hashNumber(order.number)),
        (AppStrings.gate, order.gate.name),
        (AppStrings.distance, meters == null ? '' : AppStrings.textM(meters)),
      ],
      action: AppStrings.handOverOrder,
      onAction: () {
        ref.read(orderFlowViewModelProvider.notifier).handOver();
        ref.read(handoverViewModelProvider.notifier).open();
      },
    );
  }
}
