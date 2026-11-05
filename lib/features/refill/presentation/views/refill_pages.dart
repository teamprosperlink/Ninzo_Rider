import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../online/domain/entities/online_status.dart';
import '../../../online/domain/usecases/online_usecases.dart';
import '../../../online/domain/usecases/spot_usecases.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../../shift/presentation/viewmodels/shift_flow_view_model.dart';
import '../../../stock/domain/entities/stock.dart';
import '../../domain/usecases/refill_usecases.dart';
import '../viewmodels/refill_view_model.dart';
import '../widgets/demo_refill_controls.dart';

/// Refill 01 and 02: running low or out, instead of the main map. One screen
/// by [RefillPrompt].
class RefillAlertPage extends ConsumerWidget {
  const RefillAlertPage({super.key, required this.shift, required this.status, required this.prompt});

  final Shift shift;
  final OnlineStatus status;
  final RefillPrompt prompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    final vm = ref.read(refillViewModelProvider.notifier);
    final busy = ref.watch(refillViewModelProvider.select((s) => s.busy));
    final out = prompt == RefillPrompt.outOfStock;
    final left = scooterStockOf(shift, status).portionsLeft;
    final km = shift.hubDistanceKm;
    final page = RiderScaffold(
      showBack: false,
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottomNote: out ? 'Orders resume when you’re stocked and online' : null,
      bottom: out
          ? [RiderButton('Navigate to hub', onPressed: vm.goRefill, loading: busy)]
          : [
              RiderButton('Go refill', onPressed: vm.goRefill, loading: busy),
              RiderButton.ghost('Stay online', onPressed: ref.read(shiftFlowViewModelProvider.notifier).stayOnline),
            ],
      children: [
        RiderHomeHeader(
          greeting: greeting(now),
          name: ref.watch(riderFirstNameProvider),
          status: out ? const RiderStatusPill.offline(label: 'Paused') : const RiderStatusPill('Online'),
        ),
        const SizedBox(height: 16),
        if (out) ...[
          const RiderInfoBanner(
            title: 'Time to refill',
            message: 'You’re out of stock. We’ve paused new orders so you can reload.',
            color: RiderColors.refillBanner,
          ),
          const SizedBox(height: 16),
          RiderSummaryCard(
            title: 'Refill at ${shift.hub.name}',
            rows: [
              ('Distance', km == null ? '' : distance(km)),
              ('Ride time', km == null ? '' : '${SpotRules.rideMinutes(km * 1000)} min'),
              ('Orders', 'Paused'),
            ],
          ),
        ] else ...[
          RiderInfoBanner(
            title: 'Only ${plural(left, 'item', 'items')} left',
            message: 'Plan a refill soon. Head back to ${shift.hub.name} when you’re free.',
            color: RiderColors.warningFill,
          ),
          const SizedBox(height: 16),
          RiderSpreadStats([
            ('${status.orders}', 'Orders'),
            (rupees(status.earned), 'Earned'),
            ('$left', 'Left'),
          ]),
          const SizedBox(height: 16),
          RiderSummaryCard(rows: [for (final item in status.itemsLeft) (item.name, '${item.left}')]),
        ],
      ],
    );
    if (!kDemoMode || out) return page;
    return Stack(children: [page, const DemoOutOfStockPill()]);
  }
}

/// Refill 03 "At hub": the packed items; "Scan stock" leads to Stock 01. The
/// morning's stock and a refill both come here.
class RefillAtHubPage extends ConsumerWidget {
  const RefillAtHubPage({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.read(shiftFlowViewModelProvider.notifier);
    final busy = ref.watch(shiftFlowViewModelProvider.select((s) => s.busy));
    final items = ref.watch(refillItemsProvider).value ?? const <StockItem>[];
    return RiderScaffold(
      title: 'Refill at ${shift.refill?.hubName ?? shift.hub.name}',
      onBack: ref.read(refillViewModelProvider.notifier).leaveHub,
      headerPadding: RiderHeader.flowPadding,
      backSize: 48,
      backBordered: true,
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottom: [RiderButton('Scan stock', onPressed: flow.startScanning, loading: busy)],
      children: [
        Text(
          'Collect these items, then scan them onto your scooter.',
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: 16),
        RiderPanel(gap: 16, children: [for (final item in items) _CollectRow(item)]),
      ],
    );
  }
}

class _CollectRow extends StatelessWidget {
  const _CollectRow(this.item);

  final StockItem item;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _ItemTile(item.image),
      const SizedBox(width: 12),
      Expanded(child: Text(item.name, style: RiderText.labelLarge, overflow: TextOverflow.ellipsis)),
      RiderHugText('× ${item.quantity}', style: RiderText.labelLarge),
    ],
  );
}

/// The item's photo, or the design's "Image (replace)" stand-in.
class _ItemTile extends StatelessWidget {
  const _ItemTile(this.image);

  final String? image;

  @override
  Widget build(BuildContext context) {
    final path = image;
    const size = 48.0;
    if (path != null) {
      final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(RiderRadius.m),
        child: path.startsWith('assets/')
            ? Image.asset(path, width: size, height: size, fit: BoxFit.cover, cacheWidth: pixels)
            : Image.network(path, width: size, height: size, fit: BoxFit.cover, cacheWidth: pixels),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: RiderColors.itemTile, borderRadius: BorderRadius.circular(RiderRadius.m)),
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(color: RiderColors.itemTileDot, shape: BoxShape.circle),
      ),
    );
  }
}

/// Refill 04: every portion of the refill scanned and confirmed.
class RefilledPage extends ConsumerWidget {
  const RefilledPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(refillItemsProvider).value ?? const <StockItem>[];
    final vm = ref.read(refillViewModelProvider.notifier);
    final busy = ref.watch(refillViewModelProvider.select((s) => s.busy));
    return RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(16, 52, 16, 16),
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottom: [RiderButton('Go online', onPressed: vm.finish, loading: busy)],
      children: [
        const Center(
          child: RiderTickHalo(outer: RiderColors.deliveredHaloOuter, inner: RiderColors.deliveredHaloInner),
        ),
        const SizedBox(height: 16),
        Text('Stock refilled', textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: 16),
        Text(
          '${plural(items.length, 'item', 'items')} loaded. Head back to your spot to go online.',
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: 16),
        RiderSummaryCard(rows: [for (final item in items) (item.name, '${item.quantity}')]),
      ],
    );
  }
}
