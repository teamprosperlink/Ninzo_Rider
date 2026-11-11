import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/delivery_order.dart';
import '../../../domain/usecases/delivery_usecases.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../widgets/demo_order_controls.dart';
import '../widgets/gate_map.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// The order map: Order 01 assigned, then on the way: Order 02, Order 03 once
/// the 90 s are over, Navigate 01–03 with a route issue.
class OrderMapPage extends ConsumerWidget {
  const OrderMapPage({super.key, required this.order});

  final DeliveryOrder order;

  /// Where the design draws the gate's dot, lower under a notice.



  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchOrderTime(ref);
    final state = ref.watch(orderFlowViewModelProvider);
    final vm = ref.read(orderFlowViewModelProvider.notifier);
    final time = orderClockOf(order, now);
    final assigned = order.status == DeliveryStatus.assigned;
    final issue = assigned ? null : state.issue;
    final gate = order.gate;
    final me = state.position;
    final meters = me == null ? null : const Distance().as(LengthUnit.Meter, me, gate.point);
    final away = meters == null ? '' : kilometres(meters);
    final route = state.route;
    final late = !assigned && time.late;

    final turnLabel = switch (issue) {
      RouteIssue.roadClosed || RouteIssue.offRoute => AppStrings.rerouting,
      _ => (route?.instruction.isEmpty ?? true) ? null : route!.instruction,
    };
    final turnDetail = switch (issue) {
      RouteIssue.weakSignal => AppStrings.lastKnownRoute(route?.street),
      RouteIssue.roadClosed => AppStrings.roadClosedAheadFindingTheBest,
      RouteIssue.offRoute => AppStrings.findingANewWayTo(gate.name),
      null => route?.street,
    };
    final notice = switch (issue) {
      RouteIssue.weakSignal => AppStrings.weakSignalShowingYourLastRoute,
      RouteIssue.roadClosed => AppStrings.roadClosedAheadFindingANew,
      RouteIssue.offRoute => AppStrings.youReOffRouteFindingA,
      null => null,
    };

    final ring = RiderCountdownRing(
      label: late ? AppStrings.almost : clock(time.secondsLeft),
      caption: late ? AppStrings.there : (assigned ? AppStrings.toDeliver : AppStrings.left2),
      progress: late ? 1 : time.progress,
      color: late ? RiderColors.warning : RiderColors.brand,
    );
    final reached = RiderButton(AppStrings.iVeReachedTheGate, onPressed: vm.reachedGate, loading: state.busy);
    final direction = RiderButton(
      turnButtonLabel(route?.maneuver, away),
      style: RiderButtonStyle.tinted,
      // The design's 12 × 17 arrow box; its stroke overflows the box.
      leading: SizedBox(
        width: AppSizes.s12,
        child: OverflowBox(
          maxWidth: AppSizes.s16,
          child: RiderTurnRightIcon(color: RiderColors.brand, height: AppSizes.s19, left: route?.turnsLeft ?? false, stroke: AppSizes.s2_5),
        ),
      ),
      onPressed: () => openDirections(gate.point),
    );
    final call = RiderButton.secondary(
      AppStrings.callCustomerMasked,
      onPressed: () {
        final phone = order.customerPhone;
        if (phone != null) callPhone(phone);
      },
    );

    final List<Widget> sheet;
    if (assigned) {
      sheet = [
        _Countdown(
          ring: ring,
          child: _Headline(
            pill: const RiderStatusPill(AppStrings.newOrderAssigned, tint: RiderColors.orderAssignedPill),
            title: AppStrings.deliverTo2(gate.name),
            detail: AppStrings.dotPair(gate.landmark, away),
          ),
        ),
        RiderSummaryCard(rows: [for (final item in order.items) (item.name, AppStrings.timesCount(item.quantity))]),
        RiderButton(AppStrings.navigateTo(gate.name), onPressed: vm.navigate, loading: state.busy),
        RiderButton.ghost(AppStrings.skipThisOrder, onPressed: vm.askSkip),
      ];
    } else if (late) {
      sheet = [
        _Countdown(
          ring: ring,
          child: const _Headline(
            pill: RiderStatusPill(AppStrings.aFewSecondsOver, tint: RiderColors.warningPill, color: RiderColors.warning, textColor: RiderColors.ink),
            title: AppStrings.keepGoingYouReClose,
            detail: AppStrings.theCustomerHasBeenToldYou,
          ),
        ),
        direction,
        reached,
      ];
    } else {
      sheet = [
        _Countdown(
          ring: ring,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(away.isEmpty ? '' : AppStrings.toTheGate(away), style: RiderText.subheadingMedium),
              const SizedBox(height: AppSizes.s4),
              Text(
                AppStrings.dashPair(gate.name, gate.landmark),
                style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
              ),
            ],
          ),
        ),
        if (issue == null) direction,
        reached,
        call,
      ];
    }

    return RiderMapLayout.underSheet(
      mapBuilder: (height) => GateMap(
        gate: gate.point,
        gateLabel: gate.name,
        height: height,
        gateY: notice == null ? RiderLayout.orderGateY : RiderLayout.orderGateYUnderNotice,
        rider: me,
        riderLabel: away,
        road: route?.path ?? const [],
      ),
      overlays: [
        if (notice != null) RiderWarningStrip(notice),
        if (turnLabel != null)
          RiderMapCard(
            leading: RiderTurnTile.order(left: route?.turnsLeft ?? false),
            title: turnLabel,
            subtitle: turnDetail,
          ),
      ],
      floating: [
        if (kDemoControls) Positioned(right: AppSizes.s16, top: AppSizes.s330, child: DemoOrderControls(order: order)),
      ],
      customSheet: RiderSheet(
        bottomGap: assigned ? RiderLayout.orderAssignedBottomGap : AppSizes.s12,
        minHeight: late ? RiderLayout.orderLateSheetHeight : AppSizes.s0,
        children: sheet,
      ),
    );
  }
}

/// The ring and what's next to it.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.ring, required this.child});

  final Widget ring;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ring,
      const SizedBox(width: AppSizes.s16),
      Expanded(child: child),
    ],
  );
}

class _Headline extends StatelessWidget {
  const _Headline({required this.pill, required this.title, required this.detail});

  final Widget pill;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      pill,
      const SizedBox(height: AppSizes.s8),
      Text(title, style: RiderText.subheadingMedium),
      const SizedBox(height: AppSizes.s8),
      Text(detail, style: RiderText.caption),
    ],
  );
}
