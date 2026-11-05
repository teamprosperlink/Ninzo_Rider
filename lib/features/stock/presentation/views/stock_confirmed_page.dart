import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../shift/presentation/viewmodels/shift_flow_view_model.dart';
import '../viewmodels/stock_flow_view_model.dart';

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
      bodyPadding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottom: [RiderButton('Go online', onPressed: ref.read(shiftFlowViewModelProvider.notifier).goOnline, loading: busy)],
      children: [
        const Center(child: RiderTickHalo()),
        const SizedBox(height: 16),
        Text('Stock confirmed', textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: 16),
        Text(
          '$count ${count == 1 ? 'item' : 'items'} loaded. You’re ready to go online.',
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: 16),
        RiderSummaryCard(rows: [for (final item in items) (item.name, '${item.quantity}')]),
      ],
    );
  }
}
