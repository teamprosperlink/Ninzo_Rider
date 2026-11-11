import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Stock 06: every portion scanned and confirmed; Go online unlocks. Back
/// leads Home (Shift 09).
class StockConfirmedPage extends ConsumerWidget {
  const StockConfirmedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tally = ref.watch(stockFlowViewModelProvider.select((s) => s.tally));
    final items = tally?.manifest.items ?? const [];
    final busy = ref.watch(shiftFlowViewModelProvider.select((s) => s.busy));
    final count = items.length;
    return RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s72, AppSizes.s16, AppSizes.s16),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottom: [RiderButton(AppStrings.goOnline, onPressed: ref.read(shiftFlowViewModelProvider.notifier).goOnline, loading: busy)],
      children: [
        const Center(child: RiderTickHalo()),
        const SizedBox(height: AppSizes.s16),
        Text(AppStrings.stockConfirmed, textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: AppSizes.s16),
        Text(
          AppStrings.loadedYouReReadyToGo(count, count == 1 ? AppStrings.item : AppStrings.items2),
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderSummaryCard(rows: [for (final item in items) (item.name, '${item.quantity}')]),
      ],
    );
  }
}
