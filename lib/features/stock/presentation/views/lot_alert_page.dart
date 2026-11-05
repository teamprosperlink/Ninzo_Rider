import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/scan_outcome.dart';
import '../../domain/entities/stock.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../widgets/stock_widgets.dart';

/// Stock 07 "Expired lot" and 08 "Temperature alert": this lot can't go on
/// the scooter.
class LotAlertPage extends ConsumerWidget {
  const LotAlertPage({super.key});

  static String _degrees(double c) => '${c == c.roundToDouble() ? c.toInt() : c} °C';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockFlowViewModelProvider);
    final vm = ref.read(stockFlowViewModelProvider.notifier);
    final alert = state.lotAlert;
    final warm = alert is ScanLotTooWarm;
    final (StockItem item, StockLot lot, List<(String, String)> rows) = switch (alert) {
      ScanLotExpired(:final item, :final lot, :final now) => (
        item,
        lot,
        [('Expired', lowerClockTime(lot.expiresAt!)), ('Now', lowerClockTime(now))],
      ),
      ScanLotTooWarm(:final item, :final lot) => (
        item,
        lot,
        [('Reading', _degrees(lot.temperatureC!)), ('Safe range', 'up to ${_degrees(lot.maxTemperatureC!)}')],
      ),
      _ => throw StateError('No lot alert'),
    };
    return RiderScaffold(
      title: warm ? 'Temperature alert' : 'Scan stock',
      onBack: vm.back,
      headerPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      backSize: 48,
      backBordered: true,
      bottomToEdge: true,
      bottomDecoration: stockWhiteBar,
      bottomPadding: stockWhiteBarPadding,
      bottom: [
        if (warm)
          RiderButton('Move to quarantine', onPressed: vm.moveToQuarantine)
        else
          RiderButton('Scan another item', onPressed: vm.showScanner),
      ],
      children: [
        RiderErrorBanner(
          warm
              ? 'This lot got too warm to deliver. Take it off your scooter and we’ll handle the rest.'
              : 'This lot is past its expiry time, so it can’t go on your scooter. Scan another item.',
        ),
        const SizedBox(height: 12),
        RiderPanel(
          radius: RiderRadius.field,
          children: [
            // Flutter sets half the spacing before the first letter; Figma doesn't.
            Transform.translate(
              offset: const Offset(-1, 0),
              child: Text(
                'LOT ${lot.id}',
                style: RiderText.overline.copyWith(color: RiderColors.grey, letterSpacing: 2),
              ),
            ),
            Text(item.name, style: RiderText.h4),
            for (final (label, value) in rows)
              SizedBox(
                height: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
                    Text(value, style: RiderText.labelLarge),
                  ],
                ),
              ),
          ],
        ),
        if (warm) ...[
          const SizedBox(height: 12),
          Text('We’ll move it to quarantine. It won’t count against you.', style: RiderText.caption),
        ],
      ],
    );
  }
}
