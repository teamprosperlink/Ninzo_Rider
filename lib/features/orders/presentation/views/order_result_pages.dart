import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/usecases/delivery_usecases.dart';
import '../viewmodels/handover_view_model.dart';
import '../viewmodels/order_flow_view_model.dart';

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
    this.extraBottom = 0,
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
    bodyPadding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
    bottomToEdge: true,
    bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
    bottomPadding: EdgeInsets.fromLTRB(16, 12, 16, 24 + extraBottom),
    bottom: [
      RiderButton(action, onPressed: onAction, loading: busy),
      if (secondary != null) RiderButton.ghost(secondary!, onPressed: onSecondary),
    ],
    children: [
      const Center(child: RiderTickHalo.small()),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center, style: RiderText.h4),
      const SizedBox(height: 12),
      Text(
        body,
        textAlign: TextAlign.center,
        style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
      ),
      if (rows.isNotEmpty) ...[
        const SizedBox(height: 60),
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
    title: 'Order skipped',
    body: 'We’ve passed it to the next rider. Head back to your spot for your next order.',
    rows: [
      ('Order', '#${order.number}'),
      ('Status', 'Reassigned'),
      ('Reason', order.skipReason?.label ?? ''),
    ],
    action: 'Back to your spot',
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
        'The customer cancelled this order. You’re paid ₹${pay.tripPay} for the trip. Head back to your spot for the next one.',
        [('Order value', '₹${order.amount}'), ('Status', 'Cancelled'), ('Trip pay', '₹${pay.tripPay}')],
      ),
      CancellationKind.cash => (
        'The customer cancelled this cash order. Cash orders have no cancellation charge, so there’s no trip pay this time. Head back to your spot for the next one.',
        [('Order', '#${order.number}'), ('Status', 'Cancelled'), ('Payment', order.payment.label)],
      ),
      CancellationKind.upiFull => (
        'The customer cancelled this order. It was under ₹${OrderRules.upiCancellationPay}, so you’re paid the full order amount. Head back to your spot for the next one.',
        [('Order value', '₹${order.amount}'), ('Status', 'Cancelled'), ('Trip pay', '₹${pay.tripPay}')],
      ),
    };
    return OrderResultPage(
      title: 'Order cancelled',
      body: body,
      rows: rows,
      action: 'Back to your spot',
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
      title: '${order.gate.name} confirmed',
      body: 'You’re at the gate. Hand over the order next.',
      rows: [
        ('Order', '#${order.number}'),
        ('Gate', order.gate.name),
        ('Distance', meters == null ? '' : '$meters m'),
      ],
      action: 'Hand over order',
      onAction: () {
        ref.read(orderFlowViewModelProvider.notifier).handOver();
        ref.read(handoverViewModelProvider.notifier).open();
      },
    );
  }
}
