import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/delivery_order.dart';
import '../viewmodels/order_flow_view_model.dart';

/// Order 04: why the rider can't take the order, in a sheet over a scrim.
class SkipOrderPage extends ConsumerWidget {
  const SkipOrderPage({super.key, required this.order});

  final DeliveryOrder order;

  /// The sheet runs 6px off the 800px frame in the design.
  static const _bottomGap = 6.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderFlowViewModelProvider);
    final vm = ref.read(orderFlowViewModelProvider.notifier);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarDark,
      child: Scaffold(
        backgroundColor: RiderColors.screen,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: RiderHeader(
                title: 'Order #${order.number}',
                onBack: vm.keepOrder,
                padding: RiderHeader.flowPadding,
                backSize: 48,
                backBordered: true,
              ),
            ),
            Positioned.fill(
              child: GestureDetector(onTap: vm.keepOrder, child: const ColoredBox(color: RiderColors.scrim)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 24, 16, _bottomGap + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                  color: RiderColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(RiderRadius.sheet)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Need to skip this order?', style: RiderText.h4),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us why. Your hub will reassign it right away.',
                      style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                    ),
                    const SizedBox(height: 16),
                    RiderPanel(
                      gap: 16,
                      children: [
                        for (final reason in SkipReason.values)
                          RiderRadioRow(
                            label: reason.label,
                            selected: state.reason == reason,
                            onTap: () => vm.selectReason(reason),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    RiderButton('Submit', onPressed: vm.skip, loading: state.busy),
                    const SizedBox(height: 16),
                    RiderButton.ghost('Keep this order', onPressed: vm.keepOrder),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
