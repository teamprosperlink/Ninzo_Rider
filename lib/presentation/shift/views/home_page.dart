import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/home_status.dart';
import '../../../domain/entities/shift.dart';
import '../providers/shift_providers.dart';
import '../viewmodels/shift_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Home (Shift 01–09): greeting, what to do next, today's ride and the
/// action for this moment of the day.
class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    ref.watch(shiftFlowViewModelProvider.select((s) => s.starting));
    final busy = ref.watch(shiftFlowViewModelProvider.select((s) => s.busy));
    final vm = ref.read(shiftFlowViewModelProvider.notifier);
    final status = vm.homeStatus(shift, now);
    final copy = _HomeCopy.of(status, shift);
    final starts = clockTime(shift.start);

    final List<Widget> actions = switch (status) {
      HomeStatus.stockNotRequested ||
      HomeStatus.offToday => [RiderButton(AppStrings.askHubToPrepare, onPressed: vm.askHubToPrepare, loading: busy)],
      HomeStatus.hubPreparing => [RiderButton(AppStrings.startsAt(starts), onPressed: null, dimmed: true)],
      HomeStatus.stockReady || HomeStatus.startRiding => [RiderButton(AppStrings.startRiding, onPressed: vm.startRiding)],
      HomeStatus.starting => [RiderButton(AppStrings.startRiding, onPressed: () {}, loading: true, loadingLabel: AppStrings.starting)],
      HomeStatus.collectStock => [
        RiderButton(AppStrings.goToHub, onPressed: vm.goToHub),
        RiderButton.ghost(AppStrings.goOnline, onPressed: busy ? null : vm.goOnline, dimmed: true),
      ],
      HomeStatus.finishScanning => [RiderButton(AppStrings.continueScanning, onPressed: vm.continueScanning)],
      HomeStatus.stockLoaded => [RiderButton(AppStrings.goOnline, onPressed: vm.goOnline, loading: busy)],
    };

    return RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s16),
      // Two actions sit lower, reaching 4px into the gesture area (Shift 07).
      bottomPadding: EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, actions.length > AppSizes.s1 ? AppSizes.s0 : AppSizes.s12),
      bottom: [
        for (final action in actions)
          actions.length > 1 ? Transform.translate(offset: const Offset(AppSizes.s0, AppSizes.s4), child: action) : action,
      ],
      children: [
        RiderHomeHeader(greeting: greeting(now), name: ref.watch(riderFirstNameProvider), onAvatarTap: vm.openProfile),
        const SizedBox(height: AppSizes.s16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.title, style: RiderText.h4),
              const SizedBox(height: AppSizes.s12),
              Text(copy.body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderSummaryCard(
          title: AppStrings.yourRide,
          rows: [(AppStrings.stock, copy.stock), (AppStrings.spot, shift.spot.name), (AppStrings.scooter, shift.scooter.plate)],
        ),
      ],
    );
  }
}

/// A rider with no shift today: Shift 02 "You're off today", with what's known.
/// The avatar opens Profile. There's nothing to ask the hub about until a
/// shift arrives, when Home takes over by itself; the button does nothing.
class NoShiftHomePage extends ConsumerWidget {
  const NoShiftHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    final vm = ref.read(shiftFlowViewModelProvider.notifier);
    final copy = _HomeCopy.offToday();
    return RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s16),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottom: [RiderButton(AppStrings.askHubToPrepare, onPressed: () {})],
      children: [
        RiderHomeHeader(greeting: greeting(now), name: ref.watch(riderFirstNameProvider), onAvatarTap: vm.openProfile),
        const SizedBox(height: AppSizes.s16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.title, style: RiderText.h4),
              const SizedBox(height: AppSizes.s12),
              Text(copy.body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderSummaryCard(title: AppStrings.yourRide, rows: [(AppStrings.stock, copy.stock), (AppStrings.spot, ''), (AppStrings.scooter, '')]),
      ],
    );
  }
}

/// Title, body and the Stock row for each Home state, as in the design.
class _HomeCopy {
  const _HomeCopy(this.title, this.body, this.stock);

  final String title;
  final String body;
  final String stock;

  factory _HomeCopy.offToday() => const _HomeCopy(
    AppStrings.youReOffToday,
    AppStrings.theHubWonTPackStock,
    AppStrings.notRequested,
  );

  static _HomeCopy of(HomeStatus status, Shift shift) {
    final hub = shift.hub.name;
    final stock = shift.stock;
    final away = shift.hubDistanceKm == null ? '' : AppStrings.away(distance(shift.hubDistanceKm!));
    return switch (status) {
      HomeStatus.stockNotRequested => const _HomeCopy(
        AppStrings.stockNotRequested,
        AppStrings.theHubHasnTBeenTold,
        AppStrings.notRequested,
      ),
      HomeStatus.offToday => _HomeCopy.offToday(),
      HomeStatus.hubPreparing => _HomeCopy(
        AppStrings.hubIsPackingYourStock,
        AppStrings.shiftStartsAtWeLlTell(clockTime(shift.start)),
        AppStrings.beingPacked,
      ),
      HomeStatus.stockReady => _HomeCopy(
        AppStrings.yourStockIsReady,
        AppStrings.hasPackedYourOrderStartRiding(hub),
        AppStrings.readyAt(hub),
      ),
      HomeStatus.startRiding || HomeStatus.starting => const _HomeCopy(
        AppStrings.youReOffline,
        AppStrings.checkInThenCollectYourStock,
        AppStrings.notLoadedYet,
      ),
      HomeStatus.collectStock => _HomeCopy(
        AppStrings.collectYourStock,
        AppStrings.headToScanYourItemsTo(hub, away),
        shift.stockRequest == StockRequestStatus.ready ? AppStrings.readyAt(hub) : AppStrings.beingPacked,
      ),
      HomeStatus.finishScanning => _HomeCopy(
        AppStrings.finishScanningYourStock,
        AppStrings.ofPortionsScannedScanTheRest(stock.scanned, stock.portions),
        AppStrings.ofPortions(stock.scanned, stock.portions),
      ),
      HomeStatus.stockLoaded => _HomeCopy(
        AppStrings.stockLoaded,
        AppStrings.portionsOnYourScooterYouRe(stock.portions),
        AppStrings.itemsPortions(stock.items, stock.portions),
      ),
    };
  }
}
