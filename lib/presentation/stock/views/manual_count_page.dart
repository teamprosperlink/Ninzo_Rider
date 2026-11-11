import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_keys.dart';

/// Stock 05: counts by hand, for QR codes that won't scan.
class ManualCountPage extends ConsumerWidget {
  const ManualCountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockFlowViewModelProvider);
    final vm = ref.read(stockFlowViewModelProvider.notifier);
    return RiderScaffold(
      title: AppStrings.enterCounts,
      onBack: vm.back,
      headerPadding: RiderHeader.flowPadding,
      backSize: AppSizes.s48,
      backBordered: true,
      bottomPadding: RiderLayout.stockActionsPadding,
      bottom: [RiderButton(AppStrings.saveCounts, onPressed: vm.saveCounts, loading: state.busy)],
      children: [
        Text(AppStrings.useThisIfAQrCode, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
        const SizedBox(height: AppSizes.s16),
        RiderPanel(
          gap: AppSizes.s16,
          children: [
            for (final item in state.tally!.manifest.items)
              Row(
                children: [
                  Expanded(
                    child: Text(item.name, style: RiderText.labelLarge, overflow: TextOverflow.ellipsis),
                  ),
                  RiderQuantityStepper(
                    key: Key(AppKeys.stepper(item.id)),
                    value: state.counts[item.id] ?? 0,
                    onMinus: () => vm.changeCount(item, -1),
                    onPlus: () => vm.changeCount(item, 1),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
