import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../online/domain/entities/online_status.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../orders/domain/entities/delivery_order.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../domain/usecases/shift_end_usecases.dart';
import '../viewmodels/end_shift_view_model.dart';
import '../widgets/demo_shift_end_pills.dart';

/// Shift 46–49: Home's header under a scrim, and the sheet by [EndShiftStage].
class EndShiftPage extends ConsumerWidget {
  const EndShiftPage({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchSecondClock(ref);
    final stage = ref.watch(endShiftViewModelProvider.select((s) => s.stage));
    final vm = ref.read(endShiftViewModelProvider.notifier);
    final status = ref.watch(onlineStatusProvider).value ?? const OnlineStatus();
    final totals = ShiftTotals.of(shift, status, now);
    final order = status.queue.firstOrNull;

    final (title, body, rows, actions) = switch (stage) {
      EndShiftStage.limit => (
        'Shift limit reached',
        'You chose ${_length(chosenShiftLength(shift, status))}. Wrap up, or add more time (up to 4 hours) to keep riding.',
        [
          ('Time online', hoursAndMinutes(totals.onlineTime)),
          ('Orders delivered', '${totals.orders}'),
          ('Items on scooter', '${totals.left}'),
        ],
        <Widget>[
          RiderButton('End shift', onPressed: vm.confirm),
          RiderButton.ghost('Keep riding', onPressed: vm.stay),
        ],
      ),
      EndShiftStage.blocked => (
        'Finish your delivery first',
        'Order #${order?.number ?? ''} is on its way. You can end your shift right after you hand it over.',
        [
          ('Order', '#${order?.number ?? ''}'),
          ('Gate', _gate(order)),
          ('Due in', clock(_dueIn(order, now))),
        ],
        <Widget>[
          RiderButton('View order', onPressed: vm.viewOrder),
          RiderButton.ghost('Close', onPressed: vm.stay),
        ],
      ),
      EndShiftStage.confirm || EndShiftStage.ending => (
        'End your shift?',
        'Head back to your hub and hand over any unsold stock before you finish.',
        [
          ('Orders delivered', '${totals.orders}'),
          ('Items still on scooter', '${totals.left}'),
          ('Online time', hoursAndMinutes(totals.onlineTime)),
        ],
        <Widget>[
          RiderButton(
            'End shift',
            onPressed: vm.endShift,
            loading: stage == EndShiftStage.ending,
            loadingLabel: 'Ending shift…',
          ),
          RiderButton.ghost('Stay online', onPressed: stage == EndShiftStage.ending ? () {} : vm.stay),
        ],
      ),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarDark,
      child: Scaffold(
        backgroundColor: RiderColors.screen,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 46,
                  child: RiderHomeHeader(
                    greeting: greeting(now),
                    name: ref.watch(riderFirstNameProvider),
                    status: const RiderStatusPill('Online'),
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: RiderColors.scrim)),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 12 + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                  color: RiderColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(RiderRadius.sheet)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: RiderText.h4),
                    const SizedBox(height: 8),
                    Text(body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
                    const SizedBox(height: 16),
                    RiderSummaryCard(rows: rows),
                    const SizedBox(height: 16),
                    actions.first,
                    const SizedBox(height: 16),
                    actions.last,
                  ],
                ),
              ),
            ),
            if (kDemoMode && stage == EndShiftStage.confirm) const DemoOrderComesPill(),
          ],
        ),
      ),
    );
  }

  static String _length(Duration d) {
    final minutes = d.inMinutes % 60;
    return minutes == 0 ? plural(d.inHours, 'hour', 'hours') : hoursAndMinutes(d);
  }

  static String _gate(AssignedOrder? order) {
    if (order == null) return '';
    final place = order.place;
    return place == null ? order.gate : '${order.gate} · $place';
  }

  static int _dueIn(AssignedOrder? order, DateTime now) {
    final at = order?.assignedAt;
    if (at == null) return OrderRules.window.inSeconds;
    final left = at.add(OrderRules.window).difference(now).inSeconds;
    return left < 0 ? 0 : left;
  }
}
