import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/online_status.dart';
import '../../online/providers/online_providers.dart';
import '../../../domain/entities/delivery_order.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../../domain/usecases/shift_end_usecases.dart';
import '../viewmodels/end_shift_view_model.dart';
import '../widgets/demo_shift_end_pills.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

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
        AppStrings.shiftLimitReached,
        AppStrings.youChoseWrapUpOrAdd(_length(chosenShiftLength(shift, status))),
        [
          (AppStrings.timeOnline, hoursAndMinutes(totals.onlineTime)),
          (AppStrings.ordersDelivered, '${totals.orders}'),
          (AppStrings.itemsOnScooter, '${totals.left}'),
        ],
        <Widget>[
          RiderButton(AppStrings.endShift, onPressed: vm.confirm),
          RiderButton.ghost(AppStrings.keepRiding, onPressed: vm.stay),
        ],
      ),
      EndShiftStage.blocked => (
        AppStrings.finishYourDeliveryFirst,
        AppStrings.orderIsOnItsWayYou(order?.number ?? ''),
        [
          (AppStrings.order, AppStrings.hashNumber(order?.number ?? '')),
          (AppStrings.gate, _gate(order)),
          (AppStrings.dueIn, clock(_dueIn(order, now))),
        ],
        <Widget>[
          RiderButton(AppStrings.viewOrder, onPressed: vm.viewOrder),
          RiderButton.ghost(AppStrings.close, onPressed: vm.stay),
        ],
      ),
      EndShiftStage.confirm || EndShiftStage.ending => (
        AppStrings.endYourShift,
        AppStrings.headBackToYourHubAnd,
        [
          (AppStrings.ordersDelivered, '${totals.orders}'),
          (AppStrings.itemsStillOnScooter, '${totals.left}'),
          (AppStrings.onlineTime, hoursAndMinutes(totals.onlineTime)),
        ],
        <Widget>[
          RiderButton(
            AppStrings.endShift,
            onPressed: vm.endShift,
            loading: stage == EndShiftStage.ending,
            loadingLabel: AppStrings.endingShift,
          ),
          RiderButton.ghost(AppStrings.stayOnline, onPressed: stage == EndShiftStage.ending ? () {} : vm.stay),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
                child: SizedBox(
                  height: AppSizes.s46,
                  child: RiderHomeHeader(
                    greeting: greeting(now),
                    name: ref.watch(riderFirstNameProvider),
                    status: const RiderStatusPill(AppStrings.online, tint: RiderColors.headerUnderDialog),
                    avatarTint: RiderColors.headerUnderDialog,
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: RiderColors.scrim)),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s24, AppSizes.s16, AppSizes.s12 + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                  color: RiderColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(RiderRadius.sheet)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: RiderText.h4),
                    const SizedBox(height: AppSizes.s8),
                    Text(body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
                    const SizedBox(height: AppSizes.s16),
                    RiderSummaryCard(rows: rows),
                    const SizedBox(height: AppSizes.s16),
                    actions.first,
                    const SizedBox(height: AppSizes.s16),
                    actions.last,
                  ],
                ),
              ),
            ),
            if (kDemoControls && stage == EndShiftStage.confirm) const DemoOrderComesPill(),
          ],
        ),
      ),
    );
  }

  static String _length(Duration d) {
    final minutes = d.inMinutes % AppLimits.minutesPerHour;
    return minutes == 0 ? plural(d.inHours, AppStrings.hour, AppStrings.hours) : hoursAndMinutes(d);
  }

  static String _gate(AssignedOrder? order) {
    if (order == null) return '';
    final place = order.place;
    return place == null ? order.gate : AppStrings.dotPair(order.gate, place);
  }

  static int _dueIn(AssignedOrder? order, DateTime now) {
    final at = order?.assignedAt;
    if (at == null) return OrderRules.window.inSeconds;
    final left = at.add(OrderRules.window).difference(now).inSeconds;
    return left < 0 ? 0 : left;
  }
}
