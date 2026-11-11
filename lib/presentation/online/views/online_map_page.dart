import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../../domain/entities/online_status.dart';
import '../../../domain/usecases/online_usecases.dart';
import '../providers/online_providers.dart';
import '../viewmodels/online_map_view_model.dart';
import '../widgets/demo_online_controls.dart';
import '../widgets/spot_map.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

/// The main map where orders arrive (Shift 25–32, 35), one screen by
/// [OnlineMode] and [OnlineAlert].
class OnlineMapPage extends ConsumerWidget {
  const OnlineMapPage({super.key, required this.shift});

  final Shift shift;

  /// Where the design draws the spot's dot, lower under a banner.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    ref.watch(onlineMapViewModelProvider);
    ref.watch(spotJustConfirmedProvider);
    final vm = ref.read(onlineMapViewModelProvider.notifier);
    final status = ref.watch(onlineStatusProvider).value ?? const OnlineStatus();
    final alert = vm.alert(shift, status, now);
    final mode = vm.mode(status);
    final spot = shift.spot;

    final overlays = [if (alert != null) _banner(alert, vm)];
    Widget map(double height) => SpotMap(
      spot: spot,
      height: height,
      spotY: alert == null || alert is RelocationNudgeAlert || alert is NudgeCoveredAlert || alert is ConnectionLostAlert
          ? RiderLayout.onlineMapSpotY
          : RiderLayout.onlineMapSpotYUnderBanner,
      spotLabel: AppStrings.youReHere,
      centeredLabel: true,
    );
    final floating = [if (kDemoControls) const Positioned(right: AppSizes.s16, top: AppSizes.s292, child: DemoOnlineControls())];

    if (mode == OnlineMode.orderAssigned) {
      final orders = visibleOrders(status);
      final first = orders.first;
      final busy = ref.watch(onlineMapViewModelProvider.select((s) => s.busy));
      return RiderMapLayout.underSheet(
        mapBuilder: map,
        floating: floating,
        customSheet: RiderScrollSheet(
          bottom: RiderButton(AppStrings.startOrder(first.number), onPressed: vm.startOrder, loading: busy),
          children: [
            _Heading(
              pill: AppStrings.online,
              title: AppStrings.orderIsYours(first.number),
              body: AppStrings.completeThisOrderIfMoreAre,
            ),
            _OrderCard(first, chip: AppStrings.now, active: true),
            if (orders.length > 1) ...[
              Text(AppStrings.queueOrders, style: RiderText.labelLarge),
              for (var i = 1; i < orders.length; i++) _OrderCard(orders[i], chip: i == 1 ? AppStrings.next2 : AppStrings.queued),
            ],
            _StockRow(shift: shift, status: status, onView: vm.viewStock),
          ],
        ),
      );
    }

    final (pill, title, body) = switch (mode) {
      OnlineMode.spotConfirmed => (
        AppStrings.onlineAtSpot,
        AppStrings.waitingForOrders,
        AppStrings.youConfirmedYouReAtOrders(spot.name),
      ),
      OnlineMode.quiet => (
        AppStrings.online,
        AppStrings.itSQuietRightNow,
        AppStrings.stayAtNewOrdersReachYou(spot.name),
      ),
      OnlineMode.away => (AppStrings.awayFromSpot, AppStrings.backTo(spot.name), AppStrings.headBackToStartGettingOrders),
      _ => (AppStrings.online, AppStrings.waitingForOrders, AppStrings.stayAtOrdersNearYouAre(spot.name)),
    };
    final since = status.onlineAt;
    return RiderMapLayout.underSheet(
      mapBuilder: map,
      overlays: overlays,
      floating: floating,
      sheet: [
        _Heading(
          pill: pill,
          pillWidget: alert is ConnectionLostAlert
              ? const RiderStatusPill(AppStrings.reconnecting, tint: RiderColors.warningPill, color: RiderColors.warning, textColor: RiderColors.warningText)
              : null,
          title: title,
          body: body,
        ),
        RiderStatsCard([
          ('${status.orders}', AppStrings.orders),
          (rupees(status.earned), AppStrings.earned),
          (hoursMinutes(since == null ? Duration.zero : now.difference(since)), AppStrings.online),
        ]),
        _StockRow(shift: shift, status: status, onView: vm.viewStock),
        Row(
          children: [
            // 159.5 and 156.5 wide in the design.
            Expanded(flex: AppLimits.flex1595, child: RiderButton.secondary(AppStrings.takeABreak, onPressed: vm.takeBreak)),
            const SizedBox(width: AppSizes.s12),
            Expanded(flex: AppLimits.flex1565, child: RiderButton.ghost(AppStrings.goOffline, onPressed: vm.goOffline)),
          ],
        ),
      ],
    );
  }

  Widget _banner(OnlineAlert alert, OnlineMapViewModel vm) => switch (alert) {
    ConnectionLostAlert(:final waiting) => RiderAlertBanner(
      title: AppStrings.noSignal,
      message: AppStrings.yourDeliveriesAndScansAreSaved,
      chip: waiting == 0 ? null : AppStrings.waitingToSync2(plural(waiting, AppStrings.delivery, AppStrings.deliveries)),
    ),
    RelocationNudgeAlert(:final nudge) => RiderNudgeBanner(
      title: AppStrings.ordersWaitingAt(nudge.spot.name),
      message:
          AppStrings.waitingNoRiderNearbyMinAnd(plural(nudge.ordersWaiting, AppStrings.orderIs, AppStrings.ordersAre), distance(nudge.meters / AppLimits.metersPerKm), nudge.rideMinutes),
      actions: [
        RiderNudgeButton(AppStrings.navigateToSpot, onPressed: vm.acceptNudge),
        RiderNudgeButton(AppStrings.notNow, outlined: true, onPressed: vm.dismissNudge),
      ],
    ),
    NudgeCoveredAlert(:final nudge) => RiderNudgeBanner(
      title: AppStrings.isCovered(nudge.spot.name),
      message: AppStrings.anotherRiderIsHeadingThereStay(shift.spot.name),
      actions: [RiderNudgeButton(AppStrings.gotIt, onPressed: vm.dismissNudge)],
    ),
    TimeAddedAlert(:final end) => RiderAlertBanner(
      title: AppStrings.timeAdded,
      message: AppStrings.yourShiftNowEndsAtYou(clockTime(end)),
      chip: AppStrings.ends(clockTime(end)),
      onChipTap: vm.dismissTimeAdded,
    ),
    AwayFromSpotAlert(:final meters) => RiderAlertBanner(
      title: AppStrings.headBackToYourSpot,
      message: AppStrings.ordersReachYouAtYouRe(shift.spot.name, distance(meters / AppLimits.metersPerKm)),
      chip: AppStrings.navigateToSpot,
      onChipTap: vm.navigateToSpot,
    ),
    ShiftEndingAlert(:final minutesLeft) => RiderAlertBanner(
      title: AppStrings.leftInYourShift(plural(minutesLeft, AppStrings.minute, AppStrings.minutes)),
      message: AppStrings.addTimeToKeepGettingOrders,
      chip: AppStrings.keepRiding,
      onChipTap: vm.keepRiding,
    ),
    BatteryLowAlert(:final percent) => RiderAlertBanner(
      title: AppStrings.scooterBatteryIsAt(percent),
      message: AppStrings.chargeItAtYourNextStop,
      chip: AppStrings.battery(percent),
    ),
    LowStockAlert(:final left) => RiderAlertBanner(
      title: AppStrings.onlyLeft(plural(left, AppStrings.item, AppStrings.items2)),
      message: AppStrings.ordersKeepComingUntilYouRun,
      chip: AppStrings.requestHubToPrepare,
      onChipTap: vm.requestRefill,
    ),
  };
}

class _Heading extends StatelessWidget {
  const _Heading({required this.pill, this.pillWidget, required this.title, required this.body});

  final String pill;

  /// Instead of the usual green [pill] (Shift 40).
  final Widget? pillWidget;
  final String title;
  final String body;

  /// Letter spacing of [body], to keep a tight line wrapping as designed.

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      pillWidget ?? RiderStatusPill(pill),
      const SizedBox(height: AppSizes.s8),
      Text(title, style: RiderText.h4),
      const SizedBox(height: AppSizes.s8),
      Text(body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
    ],
  );
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.shift, required this.status, required this.onView});

  final Shift shift;
  final OnlineStatus status;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(AppStrings.onScooter(plural(scooterStockOf(shift, status).shown, AppStrings.item, AppStrings.items2)), style: RiderText.labelLarge),
      RiderLink(AppStrings.viewStock, onPressed: onView, style: RiderText.link, padding: EdgeInsets.zero),
    ],
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard(this.order, {required this.chip, this.active = false});

  final AssignedOrder order;
  final String chip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cash = order.collectCash;
    return RiderOrderCard(
      title: AppStrings.order2(order.number),
      subtitle:
          AppStrings.dotTriple(order.gate, plural(order.items, AppStrings.item, AppStrings.items2), cash == null ? AppStrings.paid : AppStrings.collectCash(cash)),
      chip: chip,
      active: active,
    );
  }
}
