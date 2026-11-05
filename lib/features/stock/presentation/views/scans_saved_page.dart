import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../widgets/stock_widgets.dart';

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
      bottomDecoration: stockWhiteBar,
      bottomPadding: stockWhiteBarPadding,
      bottomGap: 12,
      bottom: [
        if (all)
          const RiderButton('Go online', onPressed: null, dimmed: true)
        else
          RiderButton('Keep scanning', onPressed: vm.showScanner),
        RiderButton.secondary('View list', onPressed: vm.showList),
      ],
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: RiderTickHalo.small()),
              const SizedBox(height: 12),
              Text(all ? 'All items scanned' : 'Scans saved', textAlign: TextAlign.center, style: RiderText.h4),
              const SizedBox(height: 12),
              Text(
                all
                    ? 'No signal. Your scans are saved. You can go online once your signal is back.'
                    : 'No signal. Your scans are saved and will sync when your signal is back.',
                textAlign: TextAlign.center,
                style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RiderSummaryCard(
          divided: false,
          radius: RiderRadius.field,
          rows: [
            ('Portions scanned', '${tally.portionsLoaded} of ${tally.portions}'),
            ('Waiting to sync', '$waiting ${waiting == 1 ? 'scan' : 'scans'}'),
            ('Last sync', lastSync == null ? '' : lowerClockTime(lastSync)),
          ],
        ),
      ],
    );
  }
}
