import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../shift/providers/shift_providers.dart';
import '../../../domain/entities/online_status.dart';
import '../viewmodels/break_view_model.dart';
import '../widgets/demo_online_controls.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_keys.dart';


/// Shift 43 "How long?".
class TakeBreakPage extends ConsumerWidget {
  const TakeBreakPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(breakViewModelProvider);
    final vm = ref.read(breakViewModelProvider.notifier);
    return RiderArtPage(
      art: RiderArtTile.pause,
      overline: AppStrings.takeABreak,
      title: AppStrings.howLong,
      body: AppStrings.ordersPauseWhileYouRestWe,
      padding: RiderLayout.breakPagePadding,
      actionsPadding: RiderLayout.breakActionsPadding,
      content: Padding(
        padding: const EdgeInsets.only(top: AppSizes.s8),
        child: Column(
          children: [
            RiderChoiceChips<BreakOption>(
              options: BreakOption.values,
              selected: state.option,
              label: (o) => o.label,
              onSelected: vm.select,
            ),
            const SizedBox(height: AppSizes.s16),
            Text(AppStrings.lunchBreaksCanBe30Min, style: RiderText.caption),
          ],
        ),
      ),
      actions: [
        RiderButton(AppStrings.startBreak, onPressed: vm.start, loading: state.busy),
        RiderButton.ghost(AppStrings.cancel, onPressed: vm.cancel),
      ],
    );
  }
}

/// Shift 44 "On a break", and 45 "Break over" once the time is up.
class OnBreakPage extends ConsumerWidget {
  const OnBreakPage({super.key, required this.state});

  final BreakState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchSecondClock(ref);
    final vm = ref.read(breakViewModelProvider.notifier);
    final busy = ref.watch(breakViewModelProvider.select((s) => s.busy));
    final over = state.isOver(now);
    final left = state.left(now);
    final minutes = state.length.inMinutes;
    final page = RiderArtPage(
      art: RiderArtTile.pause,
      overline: over ? AppStrings.breakOver : AppStrings.onABreak,
      title: over ? AppStrings.readyToRide : AppStrings.enjoyYourBreak,
      body: over
          ? AppStrings.yourBreakTimeIsUpGo
          : AppStrings.ordersArePausedWeLlNudge,
      padding: RiderLayout.breakPagePadding,
      actionsPadding: RiderLayout.breakActionsPadding,
      content: Padding(
        padding: const EdgeInsets.only(top: AppSizes.s8),
        child: Column(
          children: [
            RiderHugText(
              over ? AppStrings.plusPrefix(minutesSeconds(-left.inSeconds)) : minutesSeconds(left.inSeconds),
              style: RiderText.timer,
            ),
            const SizedBox(height: AppSizes.s12),
            SizedBox(
              width: AppSizes.s200,
              child: RiderProgressBar(state.progress(now), track: RiderColors.breakTrack),
            ),
            const SizedBox(height: AppSizes.s12),
            Text(over ? AppStrings.overYourMinBreak(minutes) : AppStrings.ofMinBreak(minutes), style: RiderText.caption),
            const SizedBox(height: AppSizes.s12),
            RiderChoiceChips<String>(
              options: const [AppStrings.text15Min],
              selected: '',
              label: (o) => o,
              onSelected: (_) => vm.addTime(),
            ),
          ],
        ),
      ),
      actions: [
        RiderButton(AppStrings.backOnline, onPressed: vm.backOnline, loading: busy),
        RiderButton.ghost(AppStrings.endShift, onPressed: vm.endShift),
      ],
    );
    if (!kDemoControls || over) return page;
    return Stack(
      children: [
        page,
        Positioned(
          right: AppSizes.s16,
          bottom: AppSizes.s180,
          child: DemoPill(
            key: const Key(AppKeys.demoBreakOver),
            label: AppStrings.demoTimeUp,
            onTap: () => vm.demoTimeUp(state.length),
          ),
        ),
      ],
    );
  }
}
