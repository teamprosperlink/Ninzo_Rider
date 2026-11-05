import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../domain/entities/online_status.dart';
import '../../domain/usecases/online_usecases.dart';
import '../providers/online_providers.dart';
import '../viewmodels/online_map_view_model.dart';
import '../widgets/demo_online_controls.dart';
import '../widgets/spot_map.dart';

/// The main map where orders arrive (Shift 25–32, 35), one screen by
/// [OnlineMode] and [OnlineAlert].
class OnlineMapPage extends ConsumerWidget {
  const OnlineMapPage({super.key, required this.shift});

  final Shift shift;

  /// Where the design draws the spot's dot, lower under a banner.
  static const _spotY = 230.0, _spotYUnderBanner = 258.0;

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
          ? _spotY
          : _spotYUnderBanner,
      spotLabel: 'You’re here',
      centeredLabel: true,
    );
    final floating = [if (kDemoMode) const Positioned(right: 16, top: 292, child: DemoOnlineControls())];

    if (mode == OnlineMode.orderAssigned) {
      final orders = visibleOrders(status);
      final first = orders.first;
      final busy = ref.watch(onlineMapViewModelProvider.select((s) => s.busy));
      return RiderMapLayout.underSheet(
        mapBuilder: map,
        floating: floating,
        customSheet: RiderScrollSheet(
          bottom: RiderButton('Start order #${first.number}', onPressed: vm.startOrder, loading: busy),
          children: [
            _Heading(
              pill: 'Online',
              title: 'Order #${first.number} is yours',
              body: 'Complete this order. If more are waiting, the next one starts right after.',
            ),
            _OrderCard(first, chip: 'Now', active: true),
            if (orders.length > 1) ...[
              Text('Queue orders', style: RiderText.labelLarge),
              for (var i = 1; i < orders.length; i++) _OrderCard(orders[i], chip: i == 1 ? 'Next' : 'Queued'),
            ],
            _StockRow(shift: shift, status: status, onView: vm.viewStock),
          ],
        ),
      );
    }

    final (pill, title, body) = switch (mode) {
      OnlineMode.spotConfirmed => (
        'Online · at spot',
        'Waiting for orders',
        'You confirmed you’re at ${spot.name}. Orders near you are assigned automatically.',
      ),
      OnlineMode.quiet => (
        'Online',
        'It’s quiet right now',
        'Stay at ${spot.name}. New orders reach you here the moment they come in.',
      ),
      OnlineMode.away => ('Away from spot', 'Back to ${spot.name}?', 'Head back to start getting orders again.'),
      _ => ('Online', 'Waiting for orders', 'Stay at ${spot.name}. Orders near you are assigned automatically.'),
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
              ? const RiderStatusPill('Reconnecting…', color: RiderColors.warning, textColor: RiderColors.warningText)
              : null,
          title: title,
          body: body,
        ),
        RiderStatsCard([
          ('${status.orders}', 'Orders'),
          (rupees(status.earned), 'Earned'),
          (hoursMinutes(since == null ? Duration.zero : now.difference(since)), 'Online'),
        ]),
        _StockRow(shift: shift, status: status, onView: vm.viewStock),
        Row(
          children: [
            // 159.5 and 156.5 wide in the design.
            Expanded(flex: 1595, child: RiderButton.secondary('Take a break', onPressed: vm.takeBreak)),
            const SizedBox(width: 12),
            Expanded(flex: 1565, child: RiderButton.ghost('Go offline', onPressed: vm.goOffline)),
          ],
        ),
      ],
    );
  }

  Widget _banner(OnlineAlert alert, OnlineMapViewModel vm) => switch (alert) {
    ConnectionLostAlert(:final waiting) => RiderAlertBanner(
      title: 'No signal',
      message: 'Your deliveries and scans are saved. They’ll sync when you’re back online.',
      chip: waiting == 0 ? null : '${plural(waiting, 'delivery', 'deliveries')} waiting to sync',
    ),
    RelocationNudgeAlert(:final nudge) => RiderNudgeBanner(
      title: 'Orders waiting at ${nudge.spot.name}',
      message:
          '${plural(nudge.ordersWaiting, 'order is', 'orders are')} waiting, no rider nearby. '
          '${distance(nudge.meters / 1000)} · ${nudge.rideMinutes} min, and the ride is paid.',
      actions: [
        RiderNudgeButton('Navigate to spot', onPressed: vm.acceptNudge),
        RiderNudgeButton('Not now', outlined: true, onPressed: vm.dismissNudge),
      ],
    ),
    NudgeCoveredAlert(:final nudge) => RiderNudgeBanner(
      title: '${nudge.spot.name} is covered',
      message: 'Another rider is heading there. Stay at ${shift.spot.name}.',
      actions: [RiderNudgeButton('Got it', onPressed: vm.dismissNudge)],
    ),
    TimeAddedAlert(:final end) => RiderAlertBanner(
      title: 'Time added',
      message: 'Your shift now ends at ${clockTime(end)}. You can add more time later.',
      chip: 'Ends ${clockTime(end)}',
      onChipTap: vm.dismissTimeAdded,
    ),
    AwayFromSpotAlert(:final meters) => RiderAlertBanner(
      title: 'Head back to your spot',
      message: 'Orders reach you at ${shift.spot.name}. You’re ${distance(meters / 1000)} away right now.',
      chip: 'Navigate to spot',
      onChipTap: vm.navigateToSpot,
    ),
    ShiftEndingAlert(:final minutesLeft) => RiderAlertBanner(
      title: '${plural(minutesLeft, 'minute', 'minutes')} left in your shift',
      message: 'Add time to keep getting orders, or your shift ends on time.',
      chip: 'Keep riding',
      onChipTap: vm.keepRiding,
    ),
    BatteryLowAlert(:final percent) => RiderAlertBanner(
      title: 'Scooter battery is at $percent%',
      message: 'Charge it at your next stop so you can keep riding.',
      chip: 'Battery $percent%',
    ),
    LowStockAlert(:final left) => RiderAlertBanner(
      title: 'Only ${plural(left, 'item', 'items')} left',
      message: 'Orders keep coming until you run out. Ask the hub to get your refill ready.',
      chip: 'Request hub to prepare',
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
      const SizedBox(height: 8),
      Text(title, style: RiderText.h4),
      const SizedBox(height: 8),
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
      Text('${plural(scooterStockOf(shift, status).shown, 'item', 'items')} on scooter', style: RiderText.labelLarge),
      RiderLink('View stock', onPressed: onView, style: RiderText.link, padding: EdgeInsets.zero),
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
      title: 'Order #${order.number}',
      subtitle:
          '${order.gate} · ${plural(order.items, 'item', 'items')} · ${cash == null ? 'Paid' : 'Collect ₹$cash cash'}',
      chip: chip,
      active: active,
    );
  }
}
