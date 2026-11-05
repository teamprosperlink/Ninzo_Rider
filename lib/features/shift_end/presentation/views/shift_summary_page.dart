import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/clock_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../online/domain/entities/online_status.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../../shift/presentation/viewmodels/shift_flow_view_model.dart';
import '../../domain/usecases/shift_end_usecases.dart';
import '../viewmodels/end_shift_view_model.dart';

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
      bodyPadding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottom: [RiderButton('Done', onPressed: ref.read(shiftFlowViewModelProvider.notifier).home)],
      children: [
        const Center(child: RiderTickHalo(innerSize: 60, iconSize: 40)),
        const SizedBox(height: 16),
        Text(name.isEmpty ? '' : 'Great shift, $name!', textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: 16),
        Text(
          'Here’s how today went.',
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: 16),
        RiderSummaryCard(
          rows: [
            ('Orders delivered', '${totals.orders}'),
            ('Average delivery time', average == null ? '' : clock(average)),
            ('Online time', hoursAndMinutes(totals.onlineTime)),
            ('Earned today', rupees(totals.earned)),
          ],
          valueColors: const {3: RiderColors.brand},
        ),
        const SizedBox(height: 16),
        RiderSummaryCard(
          title: 'Stock returned',
          rows: [
            ('Returned to hub', plural(totals.left, 'item', 'items')),
            ('Sold', plural(totals.sold, 'item', 'items')),
          ],
        ),
      ],
    );
  }
}
