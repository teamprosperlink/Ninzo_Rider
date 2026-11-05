import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/earnings_sync_view_models.dart';

const _whiteBar = BoxDecoration(color: RiderColors.white, boxShadow: riderShadow);
const _whiteBarPadding = EdgeInsets.fromLTRB(16, 12, 16, 24);
const _headerPadding = EdgeInsets.fromLTRB(16, 0, 16, 12);

TextStyle get _overline => RiderText.overline.copyWith(color: RiderColors.grey, letterSpacing: 2);

/// Earnings 01 "Today's earnings".
class EarningsPage extends ConsumerWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (earnings, orders) = ref.watch(earningsViewModelProvider);
    final vm = ref.read(earningsViewModelProvider.notifier);
    return RiderScaffold(
      title: 'Today’s earnings',
      onBack: vm.back,
      headerPadding: _headerPadding,
      backSize: 48,
      backBordered: true,
      bottomToEdge: true,
      bottomDecoration: _whiteBar,
      bottomPadding: _whiteBarPadding,
      bottom: [RiderButton('Back to waiting', onPressed: vm.back)],
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL TODAY', style: _overline),
              const SizedBox(height: 2),
              Text(rupees(earnings.total), style: RiderText.displayXl.copyWith(color: RiderColors.brand)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RiderSummaryCard(
          radius: RiderRadius.field,
          divided: false,
          rows: [
            (plural(orders, 'order', 'orders'), rupees(earnings.orderPay)),
            ('Incentives', rupees(earnings.incentives)),
            ('Repositioning (${earnings.repositionMinutes} min)', rupees(earnings.repositionPay)),
          ],
        ),
        const SizedBox(height: 12),
        Text('Restock and repositioning time is paid time.', style: RiderText.caption),
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
      title: 'Sync status',
      onBack: vm.back,
      headerPadding: _headerPadding,
      backSize: 48,
      backBordered: true,
      bottomToEdge: true,
      bottomDecoration: _whiteBar,
      bottomPadding: _whiteBarPadding,
      bottom: [RiderButton('Try again now', onPressed: vm.tryAgain)],
      children: [
        if (!state.online) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: RiderColors.tipFill, borderRadius: BorderRadius.circular(RiderRadius.m)),
            child: Text(
              'You’re offline. ${plural(events.length, 'update is', 'updates are')} saved and will send in order once you’re back.',
              style: RiderText.labelMedium.copyWith(color: RiderColors.warningText),
            ),
          ),
          const SizedBox(height: 12),
        ],
        RiderSummaryCard(
          radius: RiderRadius.field,
          divided: false,
          rows: [
            ('Waiting to sync', plural(events.length, 'event', 'events')),
            ('Last sync', last == null ? '' : lowerClockTime(last)),
            ('Connection', state.online ? 'Online' : 'Offline'),
          ],
        ),
        if (events.isNotEmpty) ...[
          const SizedBox(height: 12),
          RiderPanel(
            radius: RiderRadius.field,
            children: [
              Text('WAITING', style: _overline),
              for (final event in events)
                SizedBox(
                  height: 20,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                        ),
                      ),
                      const SizedBox(width: 8),
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
