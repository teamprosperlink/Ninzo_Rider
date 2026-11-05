import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../domain/entities/online_status.dart';
import '../viewmodels/break_view_model.dart';
import '../widgets/demo_online_controls.dart';

const _art = RiderArtTile.medium(glyph: RiderPauseGlyph());
const _pagePadding = EdgeInsets.fromLTRB(16, 72, 16, 16);
const _actionsPadding = EdgeInsets.fromLTRB(16, 8, 16, 12);

/// Shift 43 "How long?".
class TakeBreakPage extends ConsumerWidget {
  const TakeBreakPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(breakViewModelProvider);
    final vm = ref.read(breakViewModelProvider.notifier);
    return RiderArtPage(
      art: _art,
      overline: 'Take a break',
      title: 'How long?',
      body: 'Orders pause while you rest. We’ll remind you when it’s over.',
      padding: _pagePadding,
      actionsPadding: _actionsPadding,
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            RiderChoiceChips<BreakOption>(
              options: BreakOption.values,
              selected: state.option,
              label: (o) => o.label,
              onSelected: vm.select,
            ),
            const SizedBox(height: 16),
            Text('Lunch breaks can be 30 min to 1 hr', style: RiderText.caption),
          ],
        ),
      ),
      actions: [
        RiderButton('Start break', onPressed: vm.start, loading: state.busy),
        RiderButton.ghost('Cancel', onPressed: vm.cancel),
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
      art: _art,
      overline: over ? 'Break over' : 'On a break',
      title: over ? 'Ready to ride?' : 'Enjoy your break',
      body: over
          ? 'Your break time is up. Go back online to start getting orders.'
          : 'Orders are paused. We’ll nudge you when your break ends.',
      padding: _pagePadding,
      actionsPadding: _actionsPadding,
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            RiderHugText(
              over ? '+${minutesSeconds(-left.inSeconds)}' : minutesSeconds(left.inSeconds),
              style: RiderText.timer,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: RiderProgressBar(state.progress(now), track: RiderColors.breakTrack),
            ),
            const SizedBox(height: 12),
            Text(over ? 'over your $minutes min break' : 'of $minutes min break', style: RiderText.caption),
            const SizedBox(height: 12),
            RiderChoiceChips<String>(
              options: const ['+15 min'],
              selected: '',
              label: (o) => o,
              onSelected: (_) => vm.addTime(),
            ),
          ],
        ),
      ),
      actions: [
        RiderButton('Back online', onPressed: vm.backOnline, loading: busy),
        RiderButton.ghost('End shift', onPressed: vm.endShift),
      ],
    );
    if (!kDemoMode || over) return page;
    return Stack(
      children: [
        page,
        Positioned(
          right: 16,
          bottom: 180,
          child: DemoPill(
            key: const Key('demo_break_over'),
            label: 'Demo: Time up',
            onTap: () => vm.demoTimeUp(state.length),
          ),
        ),
      ],
    );
  }
}
