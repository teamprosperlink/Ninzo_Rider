import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/usecases/delivery_usecases.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../widgets/demo_order_controls.dart';
import '../widgets/gate_map.dart';

/// The order map: Order 01 assigned, then on the way: Order 02, Order 03 once
/// the 90 s are over, Navigate 01–03 with a route issue.
class OrderMapPage extends ConsumerWidget {
  const OrderMapPage({super.key, required this.order});

  final DeliveryOrder order;

  /// Where the design draws the gate's dot, lower under a notice.
  static const _gateY = 200.0, _gateYUnderNotice = 236.0;

  /// Order 03 keeps the sheet this tall, its buttons where Order 02's are.
  static const _lateSheetHeight = 388.0;

  /// Order 01's sheet runs 6px off the 800px frame in the design.
  static const _assignedBottomGap = 6.0;

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
      RouteIssue.roadClosed || RouteIssue.offRoute => 'Rerouting…',
      _ => (route?.instruction.isEmpty ?? true) ? null : route!.instruction,
    };
    final turnDetail = switch (issue) {
      RouteIssue.weakSignal => '${route?.street} · last known route',
      RouteIssue.roadClosed => 'Road closed ahead. Finding the best way',
      RouteIssue.offRoute => 'Finding a new way to ${gate.name}',
      null => route?.street,
    };
    final notice = switch (issue) {
      RouteIssue.weakSignal => 'Weak signal. Showing your last route.',
      RouteIssue.roadClosed => 'Road closed ahead. Finding a new route…',
      RouteIssue.offRoute => 'You’re off route. Finding a new way…',
      null => null,
    };

    final ring = RiderCountdownRing(
      label: late ? 'Almost' : clock(time.secondsLeft),
      caption: late ? 'there' : (assigned ? 'to deliver' : 'left'),
      progress: late ? 1 : time.progress,
      color: late ? RiderColors.warning : RiderColors.brand,
    );
    final reached = RiderButton('I’ve reached the gate', onPressed: vm.reachedGate, loading: state.busy);
    final direction = RiderButton(
      turnButtonLabel(route?.maneuver, away),
      style: RiderButtonStyle.tinted,
      // The design's 12 × 17 arrow box; its stroke overflows the box.
      leading: SizedBox(
        width: 12,
        child: OverflowBox(
          maxWidth: 16,
          child: RiderTurnRightIcon(color: RiderColors.brand, height: 19, left: route?.turnsLeft ?? false, stroke: 2.5),
        ),
      ),
      onPressed: () => openDirections(gate.point),
    );
    final call = RiderButton.secondary(
      'Call customer (masked)',
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
            pill: const RiderStatusPill('New order assigned'),
            title: 'Deliver to ${gate.name}',
            detail: '${gate.landmark} · $away',
          ),
        ),
        RiderSummaryCard(rows: [for (final item in order.items) (item.name, '× ${item.quantity}')]),
        RiderButton('Navigate to ${gate.name}', onPressed: vm.navigate, loading: state.busy),
        RiderButton.ghost('Skip this order', onPressed: vm.askSkip),
      ];
    } else if (late) {
      sheet = [
        _Countdown(
          ring: ring,
          child: const _Headline(
            pill: RiderStatusPill('A few seconds over', color: RiderColors.warning, textColor: RiderColors.ink),
            title: 'Keep going, you’re close',
            detail: 'The customer has been told you’re nearly there.',
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
              Text(away.isEmpty ? '' : '$away to the gate', style: RiderText.subheadingMedium),
              const SizedBox(height: 4),
              Text(
                '${gate.name} – ${gate.landmark}',
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
        gateY: notice == null ? _gateY : _gateYUnderNotice,
        rider: me,
        riderLabel: away,
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
        if (kDemoMode) Positioned(right: 16, top: 330, child: DemoOrderControls(order: order)),
      ],
      customSheet: RiderSheet(
        bottomGap: assigned ? _assignedBottomGap : 12,
        minHeight: late ? _lateSheetHeight : 0,
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
      const SizedBox(width: 16),
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
      const SizedBox(height: 8),
      Text(title, style: RiderText.subheadingMedium),
      const SizedBox(height: 8),
      Text(detail, style: RiderText.caption),
    ],
  );
}
