import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../domain/entities/spot_option.dart';
import '../viewmodels/choose_spot_view_model.dart';
import '../widgets/demo_choose_spot_pill.dart';

/// Shift 13–18 "Where to wait": one screen by [ChooseSpotStage].
class ChooseSpotPage extends ConsumerWidget {
  const ChooseSpotPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chooseSpotViewModelProvider);
    final vm = ref.read(chooseSpotViewModelProvider.notifier);
    final page = switch (state.stage) {
      ChooseSpotStage.noSpot => _NoSpot(onCheckAgain: vm.find),
      _ => _SpotList(state: state, vm: vm),
    };
    if (!kDemoMode) return page;
    return Stack(children: [page, const DemoSpotStatePill()]);
  }
}

/// Shift 13–17. The frames set the back button 12px into the status bar.
class _SpotList extends StatelessWidget {
  const _SpotList({required this.state, required this.vm});

  static const _intoStatusBar = 12.0;

  final ChooseSpotState state;
  final ChooseSpotViewModel vm;

  @override
  Widget build(BuildContext context) {
    final selected = state.selected;
    final grey = RiderText.bodyMedium.copyWith(color: RiderColors.grey);
    final media = MediaQuery.of(context);
    double up(double top) => top > _intoStatusBar ? top - _intoStatusBar : 0;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(top: up(media.padding.top)),
        viewPadding: media.viewPadding.copyWith(top: up(media.viewPadding.top)),
      ),
      child: RiderScaffold(
        title: 'Where to wait',
        onBack: vm.back,
        backIcon: Icons.west,
        background: RiderColors.spotScreen,
        backSize: 48,
        backBordered: true,
        headerPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        bottomToEdge: true,
        bottomPadding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: _cardShadow),
        bottom: switch (state.stage) {
          ChooseSpotStage.finding => [const RiderButton('Finding spots…', onPressed: null)],
          ChooseSpotStage.confirming => [
            RiderButton('Go to ${selected?.name}', onPressed: () {}, loading: true, loadingLabel: 'Confirming spot…'),
          ],
          ChooseSpotStage.spotFull => [
            RiderButton('Go to ${selected?.name}', onPressed: vm.confirm),
            RiderButton.ghost('Refresh', onPressed: vm.find),
          ],
          _ => [
            selected == null
                ? const RiderButton('Choose a spot', onPressed: null)
                : RiderButton('Go to ${selected.name}', onPressed: vm.confirm),
          ],
        },
        children: [
          switch (state.stage) {
            ChooseSpotStage.finding => Text('Finding spots near you…', style: grey),
            ChooseSpotStage.spotFull => _FilledBanner(name: state.filled?.name ?? ''),
            _ => Text('Pick a spot to wait at. Fewer riders means more orders for you.', style: grey),
          },
          if (state.stage == ChooseSpotStage.finding)
            for (var i = 0; i < 3; i++) ...[const SizedBox(height: 12), const _SkeletonCard()]
          else
            for (final spot in state.spots) ...[
              const SizedBox(height: 12),
              _SpotCard(
                spot: spot,
                // Shift 17 draws the button's spot like any other.
                selected: state.stage != ChooseSpotStage.spotFull && spot.name == selected?.name,
                onTap: () => vm.select(spot),
              ),
            ],
        ],
      ),
    );
  }
}

/// Drop Shadow/01: 0 2 4, black at 12%. See the note on [riderShadow].
const _cardShadow = [BoxShadow(color: Color(0x1F000000), offset: Offset(0, 2), blurRadius: 2.6)];

final _plainCard = BoxDecoration(
  color: RiderColors.white,
  borderRadius: BorderRadius.circular(RiderRadius.field),
  border: Border.all(color: RiderColors.spotCardBorder),
  boxShadow: _cardShadow,
);

/// Shift 13.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: RiderColors.spotSkeleton, borderRadius: BorderRadius.circular(height / 2)),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _plainCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(100, 14),
          const SizedBox(height: 8),
          bar(double.infinity, 6),
          const SizedBox(height: 8),
          bar(140, 12),
        ],
      ),
    );
  }
}

/// Shift 14–17: name and distance, how full it is, and the tag. Selected, it
/// has a 2px border and no shadow.
class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.spot, required this.selected, required this.onTap});

  final SpotOption spot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (String tag, Color tagColor) = switch (spot.tag) {
      SpotTag.bestForOrders => ('Best for orders', RiderColors.brand),
      SpotTag.recommended => ('Recommended', RiderColors.brand),
      SpotTag.full => ('Full', RiderColors.warningText),
      null => ('', RiderColors.grey),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: selected
            ? BoxDecoration(
                color: RiderColors.haloOuter,
                borderRadius: BorderRadius.circular(RiderRadius.field),
                border: Border.all(color: RiderColors.brand, width: 2),
              )
            : _plainCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: RiderHugText(spot.name, style: RiderText.labelLarge, overflow: TextOverflow.ellipsis)),
                RiderHugText(kilometres(spot.km * 1000), style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            _FullnessBar(
              fullness: spot.fullness,
              color: spot.isFull ? RiderColors.warning : RiderColors.brand,
              selected: selected,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: RiderHugText(
                    '${spot.taken} of ${spot.capacity} spots taken',
                    style: RiderText.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                RiderHugText(tag, style: RiderText.caption.copyWith(color: tagColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A 6px track; an empty spot still shows a 6px dot. A selected card's thicker
/// border doesn't shorten the fill, only the track (Shift 15: 98 of 292).
class _FullnessBar extends StatelessWidget {
  const _FullnessBar({required this.fullness, required this.color, required this.selected});

  static const _height = 6.0;

  final double fullness;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth + (selected ? 2 : 0)) * fullness;
      return Container(
        height: _height,
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(color: RiderColors.spotTrack, borderRadius: BorderRadius.circular(3)),
        child: Container(
          width: width < _height ? _height : width,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
      );
    },
  );
}

/// Shift 17.
class _FilledBanner extends StatelessWidget {
  const _FilledBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: RiderColors.tipFill, borderRadius: BorderRadius.circular(RiderRadius.m)),
    child: Text(
      '$name just filled up. Another rider got the last spot.',
      style: RiderText.labelMedium.copyWith(color: RiderColors.warningText),
    ),
  );
}

/// Shift 18.
class _NoSpot extends ConsumerWidget {
  const _NoSpot({required this.onCheckAgain});

  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    return RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottom: [RiderButton('Check again', onPressed: onCheckAgain)],
      children: [
        RiderHomeHeader(greeting: greeting(now), name: ref.watch(riderFirstNameProvider)),
        const SizedBox(height: 56),
        const Center(
          child: RiderArtTile.medium(glyph: Icon(Icons.pin_drop_outlined, size: 32, color: RiderColors.brand)),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 1.2),
          child: Text(
            'NO SPOT FREE',
            textAlign: TextAlign.center,
            style: RiderText.overline.copyWith(letterSpacing: 1.2),
          ),
        ),
        const SizedBox(height: 8),
        Text('No spot available right now', textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: 8),
        Text(
          'Every spot near you has a rider. We’ll tell you the moment one opens up.',
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
      ],
    );
  }
}
