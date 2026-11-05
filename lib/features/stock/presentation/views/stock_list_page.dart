import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../../core/widgets/status_views.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../widgets/stock_widgets.dart';

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
      title: 'Your stock',
      onBack: onBack ?? vm.back,
      headerPadding: RiderHeader.flowPadding,
      backSize: 48,
      backBordered: true,
      trailing: all || readOnly
          ? null
          : RiderLink('Scan', onPressed: vm.showScanner, style: RiderText.link, padding: EdgeInsets.zero),
      bottomPadding: stockActionsPadding,
      bottom: [
        if (readOnly)
          ...const <Widget>[]
        else if (offline)
          const RiderButton('Go online', onPressed: null, dimmed: true)
        else if (all)
          RiderButton('Confirm stock', onPressed: vm.confirm, loading: state.busy)
        else
          RiderButton('Scan next item', onPressed: vm.showScanner),
      ],
      children: [
        if (all)
          StockProgress(label: 'Items loaded', done: tally.itemsLoaded, total: tally.items)
        else
          StockProgress(label: 'Portions loaded', done: tally.portionsLoaded, total: tally.portions),
        const SizedBox(height: 16),
        if (offline && !readOnly) ...[
          const RiderWarningCard(title: 'Saved offline', message: 'Your scans will sync when your signal is back.'),
          const SizedBox(height: 16),
        ],
        RiderPanel(
          gap: 16,
          children: [
            for (final item in tally.manifest.items)
              StockItemRow(item: item, count: tally.count(item.id), showCount: !all),
          ],
        ),
      ],
    );
  }
}
