import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/scan_outcome.dart';
import '../../../domain/entities/stock.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Stock 07 "Expired lot" and 08 "Temperature alert": this lot can't go on
/// the scooter.
class LotAlertPage extends ConsumerWidget {
  const LotAlertPage({super.key});

  static String _degrees(double c) => AppStrings.textC(c == c.roundToDouble() ? c.toInt() : c);

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
        // The rider API's refusal doesn't say when it expired.
        [(AppStrings.expired, lot.expiresAt == null ? '' : lowerClockTime(lot.expiresAt!)), (AppStrings.now, lowerClockTime(now))],
      ),
      ScanLotTooWarm(:final item, :final lot) => (
        item,
        lot,
        // The rider API's alert has no reading.
        [
          (AppStrings.reading, lot.temperatureC == null ? '' : _degrees(lot.temperatureC!)),
          (AppStrings.safeRange, lot.maxTemperatureC == null ? '' : AppStrings.upTo(_degrees(lot.maxTemperatureC!))),
        ],
      ),
      _ => throw StateError(AppStrings.noLotAlert),
    };
    return RiderScaffold(
      title: warm ? AppStrings.temperatureAlert : AppStrings.scanStock,
      onBack: vm.back,
      headerPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s12),
      backSize: AppSizes.s48,
      backBordered: true,
      bottomToEdge: true,
      bottomDecoration: RiderLayout.stockWhiteBar,
      bottomPadding: RiderLayout.stockWhiteBarPadding,
      bottom: [
        if (warm)
          RiderButton(AppStrings.moveToQuarantine, onPressed: vm.moveToQuarantine)
        else
          RiderButton(AppStrings.scanAnotherItem, onPressed: vm.showScanner),
      ],
      children: [
        RiderErrorBanner(
          warm
              ? AppStrings.thisLotGotTooWarmTo
              : AppStrings.thisLotIsPastItsExpiry,
        ),
        const SizedBox(height: AppSizes.s12),
        RiderPanel(
          radius: RiderRadius.field,
          children: [
            // Flutter sets half the spacing before the first letter; Figma doesn't.
            Transform.translate(
              offset: const Offset(-AppSizes.s1, AppSizes.s0),
              child: Text(
                AppStrings.lot(lot.id),
                style: RiderText.overlineSpaced2.copyWith(color: RiderColors.grey),
              ),
            ),
            Text(item.name, style: RiderText.h4),
            for (final (label, value) in rows)
              SizedBox(
                height: AppSizes.s20,
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
          const SizedBox(height: AppSizes.s12),
          Text(AppStrings.weLlMoveItToQuarantine, style: RiderText.caption),
        ],
      ],
    );
  }
}
