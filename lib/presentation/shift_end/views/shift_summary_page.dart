import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/online_status.dart';
import '../../online/providers/online_providers.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../../domain/usecases/shift_end_usecases.dart';
import '../viewmodels/end_shift_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

/// Shift 50: how the day went. "Done" → Shift 05.
class ShiftSummaryPage extends ConsumerWidget {
  const ShiftSummaryPage({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(onlineStatusProvider).value ?? const OnlineStatus();
    final endedAt = ref.watch(endShiftViewModelProvider.select((s) => s.endedAt)) ?? status.endedAt;
    final totals = ShiftTotals.of(shift, status, endedAt ?? ref.read(clockProvider)());
    final name = ref.watch(riderFirstNameProvider);
    final average = totals.averageDeliverySeconds;
    return RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s24, AppSizes.s16, AppSizes.s16),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottom: [RiderButton(AppStrings.done, onPressed: ref.read(shiftFlowViewModelProvider.notifier).home)],
      children: [
        const Center(child: RiderTickHalo(innerSize: AppSizes.s60, iconSize: AppSizes.s40)),
        const SizedBox(height: AppSizes.s16),
        Text(name.isEmpty ? '' : AppStrings.greatShift(name), textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: AppSizes.s16),
        Text(
          AppStrings.hereSHowTodayWent,
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderSummaryCard(
          rows: [
            (AppStrings.ordersDelivered, '${totals.orders}'),
            (AppStrings.averageDeliveryTime, average == null ? '' : clock(average)),
            (AppStrings.onlineTime, hoursAndMinutes(totals.onlineTime)),
            (AppStrings.earnedToday, rupees(totals.earned)),
          ],
          valueColors: const {AppLimits.summaryHighlightRow: RiderColors.brand},
        ),
        const SizedBox(height: AppSizes.s16),
        RiderSummaryCard(
          title: AppStrings.stockReturned,
          rows: [
            (AppStrings.returnedToHub, plural(totals.left, AppStrings.item, AppStrings.items2)),
            (AppStrings.sold, plural(totals.sold, AppStrings.item, AppStrings.items2)),
          ],
        ),
      ],
    );
  }
}
