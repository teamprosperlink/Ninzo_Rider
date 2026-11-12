import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/constants/demo_data.dart';
import '../../online/widgets/demo_online_controls.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/delivery_order.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_keys.dart';

/// Demo mode only, not part of the design: amber pills on the order map that
/// play what a demo can't produce by itself. One plays the route (Navigate
/// 01–03, Order 03), the other the customer cancelling (Navigate 04–06), a
/// different way each time.
class DemoOrderControls extends ConsumerStatefulWidget {
  const DemoOrderControls({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<DemoOrderControls> createState() => _DemoOrderControlsState();
}

enum _RouteStep {
  weakSignal(AppStrings.weakSignal),
  roadClosed(AppStrings.roadClosed),
  offRoute(AppStrings.offRoute),
  onRoute(AppStrings.backOnRoute),
  late(AppStrings.runningLate);

  const _RouteStep(this.label);

  final String label;
}

class _DemoOrderControlsState extends ConsumerState<DemoOrderControls> {
  static var _nextRoute = _RouteStep.weakSignal;

  // Survives the order: the next one plays the next way of cancelling.
  static var _nextCancel = 0;

  void _playRoute() {
    final demo = ref.read(demoDeliveryProvider);
    if (demo == null) return;
    final step = _nextRoute;
    switch (step) {
      case _RouteStep.weakSignal:
        demo.playRouteIssue(RouteIssue.weakSignal);
      case _RouteStep.roadClosed:
        demo.playRouteIssue(RouteIssue.roadClosed);
      case _RouteStep.offRoute:
        demo.playRouteIssue(RouteIssue.offRoute);
      case _RouteStep.onRoute:
        demo.playRouteIssue(null);
      case _RouteStep.late:
        demo.playLate(widget.order.id);
    }
    setState(() => _nextRoute = _RouteStep.values[(step.index + 1) % _RouteStep.values.length]);
  }

  void _playCancel() {
    final demo = ref.read(demoDeliveryProvider);
    if (demo == null) return;
    final (payment, amount) = DemoData.cancellations[_nextCancel];
    _nextCancel = (_nextCancel + 1) % DemoData.cancellations.length;
    _nextRoute = _RouteStep.weakSignal;
    demo.playCancel(widget.order.id, payment, amount, DemoData.cancellationPay(payment, amount));
  }

  @override
  Widget build(BuildContext context) {
    if (!kDemoControls) return const SizedBox.shrink();
    final (payment, amount) = DemoData.cancellations[_nextCancel];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.order.status == DeliveryStatus.onTheWay) ...[
          DemoPill(key: const Key(AppKeys.demoRouteNext), label: AppStrings.demo(_nextRoute.label), onTap: _playRoute),
          const SizedBox(height: AppSizes.s8),
          DemoPill(
            key: const Key(AppKeys.demoCancelNext),
            label: AppStrings.demoCustomerCancels(payment == OrderPayment.cash ? AppStrings.cash2 : AppStrings.upi, amount),
            onTap: _playCancel,
          ),
        ],
      ],
    );
  }
}

/// Demo mode only: the "Camera" pill on the gate screen.
class DemoGateControls extends ConsumerWidget {
  const DemoGateControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDemoControls) return const SizedBox.shrink();
    final on = ref.watch(orderFlowViewModelProvider.select((s) => s.cameraOn));
    return DemoPill(
      key: const Key(AppKeys.demoGateCamera),
      label: AppStrings.demoCamera(on ? AppStrings.textOn : AppStrings.off),
      onTap: () => ref.read(orderFlowViewModelProvider.notifier).demoSetCameraOff(on),
    );
  }
}

/// Demo mode only: the phone's signal during a handover, for Handover 10.
class DemoHandoverControls extends ConsumerWidget {
  const DemoHandoverControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDemoControls) return const SizedBox.shrink();
    final online = ref.watch(orderFlowViewModelProvider.select((s) => s.signal));
    return DemoPill(
      key: const Key(AppKeys.demoHandoverSignal),
      label: AppStrings.demoSignal(online ? AppStrings.textOn : AppStrings.off),
      onTap: () {
        final signal = ref.read(demoSignalProvider);
        if (signal != null) signal.online = !signal.online;
      },
    );
  }
}

/// Demo mode only: Handover 11 → 06, the rest of the queue goes elsewhere.
class DemoDeliveredControls extends ConsumerWidget {
  const DemoDeliveredControls({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDemoControls) return const SizedBox.shrink();
    return DemoPill(
      key: const Key(AppKeys.demoNoMoreOrders),
      label: AppStrings.demoNoMoreOrders,
      onTap: () => ref.read(demoDeliveryProvider)?.playNoMoreOrders(orderId),
    );
  }
}
