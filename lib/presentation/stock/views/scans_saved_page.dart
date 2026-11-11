import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Stock 13 "Scans saved" while there's more to scan; 14 "All items scanned",
/// where Go online waits for signal.
class ScansSavedPage extends ConsumerWidget {
  const ScansSavedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockFlowViewModelProvider);
    final vm = ref.read(stockFlowViewModelProvider.notifier);
    final tally = state.tally!;
    final all = tally.allScanned;
    final waiting = tally.waitingToSync;
    final lastSync = state.lastSyncAt;
    return RiderScaffold(
      showBack: false,
      bottomToEdge: true,
      bottomDecoration: RiderLayout.stockWhiteBar,
      bottomPadding: RiderLayout.stockWhiteBarPadding,
      bottomGap: AppSizes.s12,
      bottom: [
        if (all)
          const RiderButton(AppStrings.goOnline, onPressed: null, dimmed: true)
        else
          RiderButton(AppStrings.keepScanning, onPressed: vm.showScanner),
        RiderButton.secondary(AppStrings.viewList, onPressed: vm.showList),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.s48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: RiderTickHalo.small()),
              const SizedBox(height: AppSizes.s12),
              Text(all ? AppStrings.allItemsScanned : AppStrings.scansSaved, textAlign: TextAlign.center, style: RiderText.h4),
              const SizedBox(height: AppSizes.s12),
              Text(
                all
                    ? AppStrings.noSignalYourScansAreSaved
                    : AppStrings.noSignalYourScansAreSaved2,
                textAlign: TextAlign.center,
                style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s12),
        RiderSummaryCard(
          divided: false,
          radius: RiderRadius.field,
          rows: [
            (AppStrings.portionsScanned, AppStrings.textOf(tally.portionsLoaded, tally.portions)),
            (AppStrings.waitingToSync, AppStrings.spacePair(waiting, waiting == 1 ? AppStrings.scan2 : AppStrings.scans)),
            (AppStrings.lastSync, lastSync == null ? '' : lowerClockTime(lastSync)),
          ],
        ),
      ],
    );
  }
}
