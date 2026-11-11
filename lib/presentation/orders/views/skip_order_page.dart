import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/delivery_order.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Order 04: why the rider can't take the order, in a sheet over a scrim.
class SkipOrderPage extends ConsumerWidget {
  const SkipOrderPage({super.key, required this.order});

  final DeliveryOrder order;


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
                title: AppStrings.order2(order.number),
                onBack: vm.keepOrder,
                padding: RiderHeader.flowPadding,
                backSize: AppSizes.s48,
                backBordered: true,
              ),
            ),
            Positioned.fill(
              child: GestureDetector(onTap: vm.keepOrder, child: const ColoredBox(color: RiderColors.scrim)),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s24, AppSizes.s16, RiderLayout.skipOrderBottomGap + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                  color: RiderColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(RiderRadius.sheet)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(AppStrings.needToSkipThisOrder, style: RiderText.h4),
                    const SizedBox(height: AppSizes.s8),
                    Text(
                      AppStrings.tellUsWhyYourHubWill,
                      style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                    ),
                    const SizedBox(height: AppSizes.s16),
                    RiderPanel(
                      gap: AppSizes.s16,
                      children: [
                        for (final reason in SkipReason.values)
                          RiderRadioRow(
                            label: reason.label,
                            selected: state.reason == reason,
                            onTap: () => vm.selectReason(reason),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.s16),
                    RiderButton(AppStrings.submit, onPressed: vm.skip, loading: state.busy),
                    const SizedBox(height: AppSizes.s16),
                    RiderButton.ghost(AppStrings.keepThisOrder, onPressed: vm.keepOrder),
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
