import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../core/widgets/status_views.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../widgets/stock_widgets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Stock 03 still scanning; 15 all scanned; 16 all scanned, saved offline
/// (Go online waits for signal).
///
/// [onBack] makes it the read-only list behind "View stock" on the main map:
/// no scanning or confirming from there.
class StockListPage extends ConsumerWidget {
  const StockListPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockFlowViewModelProvider);
    final vm = ref.read(stockFlowViewModelProvider.notifier);
    final tally = state.tally;
    if (tally == null) return const BlankScreen();
    final readOnly = onBack != null;
    final all = tally.allScanned;
    final offline = all && state.savedOffline;
    return RiderScaffold(
      title: AppStrings.yourStock,
      onBack: onBack ?? vm.back,
      headerPadding: RiderHeader.flowPadding,
      backSize: AppSizes.s48,
      backBordered: true,
      // An open load can take another lot until it's confirmed.
      trailing: (all && !tally.manifest.open) || readOnly
          ? null
          : RiderLink(AppStrings.scan, onPressed: vm.showScanner, style: RiderText.link, padding: EdgeInsets.zero),
      bottomPadding: RiderLayout.stockActionsPadding,
      bottom: [
        if (readOnly)
          ...const <Widget>[]
        else if (offline)
          const RiderButton(AppStrings.goOnline, onPressed: null, dimmed: true)
        else if (all)
          RiderButton(AppStrings.confirmStock, onPressed: vm.confirm, loading: state.busy)
        else
          RiderButton(AppStrings.scanNextItem, onPressed: vm.showScanner),
      ],
      children: [
        if (all)
          StockProgress(label: AppStrings.itemsLoaded, done: tally.itemsLoaded, total: tally.items)
        else
          StockProgress(label: AppStrings.portionsLoaded, done: tally.portionsLoaded, total: tally.portions),
        const SizedBox(height: AppSizes.s16),
        if (offline && !readOnly) ...[
          const RiderWarningCard(title: AppStrings.savedOffline, message: AppStrings.yourScansWillSyncWhenYour),
          const SizedBox(height: AppSizes.s16),
        ],
        RiderPanel(
          gap: AppSizes.s16,
          children: [
            for (final item in tally.manifest.items)
              StockItemRow(item: item, count: tally.count(item.id), showCount: !all),
          ],
        ),
      ],
    );
  }
}
