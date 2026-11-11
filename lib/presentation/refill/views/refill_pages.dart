import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/online_status.dart';
import '../../../domain/usecases/online_usecases.dart';
import '../../../domain/usecases/spot_usecases.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../../domain/entities/stock.dart';
import '../../../domain/usecases/refill_usecases.dart';
import '../viewmodels/refill_view_model.dart';
import '../widgets/demo_refill_controls.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';
import '../../../core/constants/app_assets.dart';

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
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottomNote: out ? AppStrings.ordersResumeWhenYouReStocked : null,
      bottom: out
          ? [RiderButton(AppStrings.navigateToHub, onPressed: vm.goRefill, loading: busy)]
          : [
              RiderButton(AppStrings.goRefill, onPressed: vm.goRefill, loading: busy),
              RiderButton.ghost(AppStrings.stayOnline, onPressed: ref.read(shiftFlowViewModelProvider.notifier).stayOnline),
            ],
      children: [
        RiderHomeHeader(
          greeting: greeting(now),
          name: ref.watch(riderFirstNameProvider),
          status: out ? const RiderStatusPill.offline(label: AppStrings.paused) : const RiderStatusPill(AppStrings.online, tint: RiderColors.greenPillOnScreen),
        ),
        const SizedBox(height: AppSizes.s16),
        if (out) ...[
          const RiderInfoBanner(
            title: AppStrings.timeToRefill,
            message: AppStrings.youReOutOfStockWe,
            color: RiderColors.refillBanner,
          ),
          const SizedBox(height: AppSizes.s16),
          RiderSummaryCard(
            title: AppStrings.refillAt(shift.hub.name),
            rows: [
              (AppStrings.distance, km == null ? '' : distance(km)),
              (AppStrings.rideTime, km == null ? '' : AppStrings.min(SpotRules.rideMinutes(km * AppLimits.metersPerKm))),
              (AppStrings.orders, AppStrings.paused),
            ],
          ),
        ] else ...[
          RiderInfoBanner(
            title: AppStrings.onlyLeft(plural(left, AppStrings.item, AppStrings.items2)),
            message: AppStrings.planARefillSoonHeadBack(shift.hub.name),
            color: RiderColors.warningFill,
          ),
          const SizedBox(height: AppSizes.s16),
          RiderSpreadStats([
            ('${status.orders}', AppStrings.orders),
            (rupees(status.earned), AppStrings.earned),
            ('$left', AppStrings.left),
          ]),
          const SizedBox(height: AppSizes.s16),
          RiderSummaryCard(rows: [for (final item in status.itemsLeft) (item.name, '${item.left}')]),
        ],
      ],
    );
    if (!kDemoControls || out) return page;
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
      title: AppStrings.refillAt(shift.refill?.hubName ?? shift.hub.name),
      onBack: ref.read(refillViewModelProvider.notifier).leaveHub,
      headerPadding: RiderHeader.flowPadding,
      backSize: AppSizes.s48,
      backBordered: true,
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottom: [RiderButton(AppStrings.scanStock, onPressed: flow.startScanning, loading: busy)],
      children: [
        Text(
          AppStrings.collectTheseItemsThenScanThem,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderPanel(gap: AppSizes.s16, children: [for (final item in items) _CollectRow(item)]),
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
      const SizedBox(width: AppSizes.s12),
      Expanded(child: Text(item.name, style: RiderText.labelLarge, overflow: TextOverflow.ellipsis)),
      RiderHugText(AppStrings.timesCount(item.quantity), style: RiderText.labelLarge),
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
    const size = AppSizes.s48_0;
    if (path != null) {
      final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(RiderRadius.m),
        child: path.startsWith(AppAssets.folder)
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
        width: AppSizes.s24,
        height: AppSizes.s24,
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
      bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s52, AppSizes.s16, AppSizes.s16),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottom: [RiderButton(AppStrings.goOnline, onPressed: vm.finish, loading: busy)],
      children: [
        const Center(
          child: RiderTickHalo(outer: RiderColors.deliveredHaloOuter, inner: RiderColors.deliveredHaloInner),
        ),
        const SizedBox(height: AppSizes.s16),
        Text(AppStrings.stockRefilled, textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: AppSizes.s16),
        Text(
          AppStrings.loadedHeadBackToYourSpot(plural(items.length, AppStrings.item, AppStrings.items2)),
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderSummaryCard(rows: [for (final item in items) (item.name, '${item.quantity}')]),
      ],
    );
  }
}
