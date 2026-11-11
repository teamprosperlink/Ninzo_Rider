import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/earnings_sync_view_models.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';


TextStyle get _overline => RiderText.overlineSpaced2.copyWith(color: RiderColors.grey);

/// Earnings 01 "Today's earnings".
class EarningsPage extends ConsumerWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (earnings, orders) = ref.watch(earningsViewModelProvider);
    final vm = ref.read(earningsViewModelProvider.notifier);
    return RiderScaffold(
      title: AppStrings.todaySEarnings,
      onBack: vm.back,
      headerPadding: RiderLayout.earningsSyncHeaderPadding,
      backSize: AppSizes.s48,
      backBordered: true,
      bottomToEdge: true,
      bottomDecoration: RiderLayout.earningsSyncWhiteBar,
      bottomPadding: RiderLayout.earningsSyncWhiteBarPadding,
      bottom: [RiderButton(AppStrings.backToWaiting, onPressed: vm.back)],
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RiderLeftOverline(AppStrings.totalToday, style: _overline),
              const SizedBox(height: AppSizes.s2),
              Text(rupees(earnings.total), style: RiderText.displayXl.copyWith(color: RiderColors.brand)),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s12),
        RiderSummaryCard(
          radius: RiderRadius.field,
          divided: false,
          rows: [
            (plural(orders, AppStrings.order3, AppStrings.orders2), rupees(earnings.orderPay)),
            (AppStrings.incentives, rupees(earnings.incentives)),
            (AppStrings.repositioningMin(earnings.repositionMinutes), rupees(earnings.repositionPay)),
          ],
        ),
        const SizedBox(height: AppSizes.s12),
        Text(AppStrings.restockAndRepositioningTimeIsPaid, style: RiderText.caption),
      ],
    );
  }
}

/// Sync 01 "Sync status".
class SyncStatusPage extends ConsumerWidget {
  const SyncStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncStatusViewModelProvider);
    final vm = ref.read(syncStatusViewModelProvider.notifier);
    final events = state.snapshot.events;
    final last = state.snapshot.lastSync;
    return RiderScaffold(
      title: AppStrings.syncStatus,
      onBack: vm.back,
      headerPadding: RiderLayout.earningsSyncHeaderPadding,
      backSize: AppSizes.s48,
      backBordered: true,
      bottomToEdge: true,
      bottomDecoration: RiderLayout.earningsSyncWhiteBar,
      bottomPadding: RiderLayout.earningsSyncWhiteBarPadding,
      bottom: [RiderButton(AppStrings.tryAgainNow, onPressed: vm.tryAgain)],
      children: [
        if (!state.online) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s12),
            decoration: BoxDecoration(color: RiderColors.tipFill, borderRadius: BorderRadius.circular(RiderRadius.m)),
            child: Text(
              AppStrings.youReOfflineSavedAndWill(plural(events.length, AppStrings.updateIs, AppStrings.updatesAre)),
              style: RiderText.labelMedium.copyWith(color: RiderColors.warningText),
            ),
          ),
          const SizedBox(height: AppSizes.s12),
        ],
        RiderSummaryCard(
          radius: RiderRadius.field,
          divided: false,
          rows: [
            (AppStrings.waitingToSync, plural(events.length, AppStrings.event, AppStrings.events)),
            (AppStrings.lastSync, last == null ? '' : lowerClockTime(last)),
            (AppStrings.connection, state.online ? AppStrings.online : AppStrings.offline),
          ],
        ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: AppSizes.s12),
          RiderPanel(
            radius: RiderRadius.field,
            children: [
              RiderLeftOverline(AppStrings.waiting, style: _overline),
              for (final event in events)
                SizedBox(
                  height: AppSizes.s20,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.label,
                          maxLines: AppLimits.oneLine,
                          overflow: TextOverflow.ellipsis,
                          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                        ),
                      ),
                      const SizedBox(width: AppSizes.s8),
                      Text(lowerClockTime(event.at), style: RiderText.labelLarge),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
