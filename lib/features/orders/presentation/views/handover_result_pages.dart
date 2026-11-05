import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../online/domain/entities/online_status.dart';
import '../../../online/domain/usecases/online_usecases.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/usecases/handover_usecases.dart';
import '../viewmodels/handover_view_model.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../viewmodels/problem_report_view_model.dart';
import '../widgets/demo_order_controls.dart';
import 'order_result_pages.dart';

/// Handover 12: cash orders have no code. The rider handles change, so there's
/// no short-cash screen.
class CollectCashPage extends ConsumerWidget {
  const CollectCashPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OrderResultPage(
    title: 'Collect ₹${order.amount}',
    body: 'Cash on delivery. Collect the full amount before you hand over the order.',
    rows: [('Order', '#${order.number}'), ('Payment', 'Cash'), ('Amount', '₹${order.amount}')],
    action: 'I’ve collected ₹${order.amount}',
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
    title: 'Check the order details',
    body: 'Ask the customer to open their order. Match the number and items, then hand over.',
    rows: [
      ('Order number', '#${order.number}'),
      ('Items', plural(order.itemCount, 'item', 'items')),
      ('Payment', 'Paid by UPI'),
    ],
    action: 'Details match, hand over',
    busy: ref.watch(handoverViewModelProvider.select((s) => s.busy)),
    onAction: ref.read(handoverViewModelProvider.notifier).detailsMatch,
    secondary: 'Details don’t match',
    onSecondary: () => ref.read(problemReportViewModelProvider.notifier).open(),
    extraBottom: 16,
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
      title: 'Handover saved',
      body: 'No signal at the gate. It’s saved on your phone and will sync by itself.',
      rows: [
        ('Order', '#${order.number}'),
        ('Waiting to sync', plural(state.local.saved.length, 'event', 'events')),
        ('Last sync', lastSync == null ? '' : lowerClockTime(lastSync)),
      ],
      action: 'Back to waiting',
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
      bodyPadding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
      bottomPadding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      bottom: [
        if (next == null)
          RiderButton('Back to waiting', onPressed: vm.backToSpot, loading: busy)
        else
          RiderButton('Start next order', onPressed: vm.startNext, loading: busy),
      ],
      children: [
        const Center(
          child: RiderTickHalo(outer: RiderColors.deliveredHaloOuter, inner: RiderColors.deliveredHaloInner),
        ),
        const SizedBox(height: 16),
        Text('Delivered in $time', textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: 16),
        Text(
          next == null ? 'Nice work. The customer has their order.' : 'Nice work. Your next order is ready to go.',
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: 16),
        RiderSummaryCard(
          rows: [('Order', '#${order.number}'), ('Time to gate', time), ('Earned', '₹${order.riderFee}')],
          valueColors: const {2: RiderColors.brand},
        ),
        const SizedBox(height: 16),
        RiderSummaryCard(
          rows: [
            if (next == null)
              ('Items left on scooter', '${shift == null ? 0 : scooterStockOf(shift, status).portionsLeft}')
            else
              ('Next · #${next.number} · ${next.gate}', plural(next.items, 'item', 'items')),
          ],
        ),
      ],
    );
    if (!kDemoMode || next == null) return page;
    return Stack(
      fit: StackFit.expand,
      children: [
        page,
        Positioned(
          top: MediaQuery.viewPaddingOf(context).top + 12,
          right: 16,
          child: DemoDeliveredControls(orderId: order.id),
        ),
      ],
    );
  }
}
