import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../shift/providers/shift_providers.dart';
import '../../../domain/entities/spot_option.dart';
import '../viewmodels/choose_spot_view_model.dart';
import '../widgets/demo_choose_spot_pill.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

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
    if (!kDemoControls) return page;
    return Stack(children: [page, const DemoSpotStatePill()]);
  }
}

/// Shift 13–17. The frames set the back button 12px into the status bar.
class _SpotList extends StatelessWidget {
  const _SpotList({required this.state, required this.vm});


  final ChooseSpotState state;
  final ChooseSpotViewModel vm;

  @override
  Widget build(BuildContext context) {
    final selected = state.selected;
    final grey = RiderText.bodyMedium.copyWith(color: RiderColors.grey);
    final media = MediaQuery.of(context);
    double up(double top) => top > RiderLayout.chooseSpotIntoStatusBar ? top - RiderLayout.chooseSpotIntoStatusBar : 0;
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(top: up(media.padding.top)),
        viewPadding: media.viewPadding.copyWith(top: up(media.viewPadding.top)),
      ),
      child: RiderScaffold(
        title: AppStrings.whereToWait,
        onBack: vm.back,
        backIcon: Icons.west,
        background: RiderColors.spotScreen,
        backSize: AppSizes.s48,
        backBordered: true,
        headerPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s12),
        bottomToEdge: true,
        bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s12, AppSizes.s16, AppSizes.s24),
        bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: RiderLayout.chooseSpotCardShadow),
        bottom: switch (state.stage) {
          ChooseSpotStage.finding => [const RiderButton(AppStrings.findingSpots, onPressed: null)],
          ChooseSpotStage.confirming => [
            RiderButton(AppStrings.goTo(selected?.name), onPressed: () {}, loading: true, loadingLabel: AppStrings.confirmingSpot),
          ],
          ChooseSpotStage.spotFull => [
            RiderButton(AppStrings.goTo(selected?.name), onPressed: vm.confirm),
            RiderButton.ghost(AppStrings.refresh, onPressed: vm.find),
          ],
          _ => [
            selected == null
                ? const RiderButton(AppStrings.chooseASpot, onPressed: null)
                : RiderButton(AppStrings.goTo(selected.name), onPressed: vm.confirm),
          ],
        },
        children: [
          switch (state.stage) {
            ChooseSpotStage.finding => Text(AppStrings.findingSpotsNearYou, style: grey),
            ChooseSpotStage.spotFull => _FilledBanner(name: state.filled?.name ?? ''),
            _ => Text(AppStrings.pickASpotToWaitAt, style: grey),
          },
          if (state.stage == ChooseSpotStage.finding)
            for (var i = 0; i < AppLimits.skeletonCards; i++) ...[const SizedBox(height: AppSizes.s12), const _SkeletonCard()]
          else
            for (final spot in state.spots) ...[
              const SizedBox(height: AppSizes.s12),
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

final _plainCard = BoxDecoration(
  color: RiderColors.white,
  borderRadius: BorderRadius.circular(RiderRadius.field),
  border: Border.all(color: RiderColors.spotCardBorder),
  boxShadow: RiderLayout.chooseSpotCardShadow,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s14),
      decoration: _plainCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(AppSizes.s100, AppSizes.s14),
          const SizedBox(height: AppSizes.s8),
          bar(double.infinity, AppSizes.s6),
          const SizedBox(height: AppSizes.s8),
          bar(AppSizes.s140, AppSizes.s12),
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
      SpotTag.bestForOrders => (AppStrings.bestForOrders, RiderColors.brand),
      SpotTag.recommended => (AppStrings.recommended, RiderColors.brand),
      SpotTag.full => (AppStrings.full, RiderColors.warningText),
      null => ('', RiderColors.grey),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s14),
        decoration: selected
            ? BoxDecoration(
                color: RiderColors.haloOuter,
                borderRadius: BorderRadius.circular(RiderRadius.field),
                border: Border.all(color: RiderColors.brand, width: AppSizes.s2),
              )
            : _plainCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: RiderHugText(spot.name, style: RiderText.labelLarge, overflow: TextOverflow.ellipsis)),
                RiderHugText(kilometres(spot.km * AppLimits.metersPerKm), style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            _FullnessBar(
              fullness: spot.fullness,
              color: spot.isFull ? RiderColors.warning : RiderColors.brand,
              selected: selected,
            ),
            const SizedBox(height: AppSizes.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: RiderHugText(
                    AppStrings.ofSpotsTaken(spot.taken, spot.capacity),
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


  final double fullness;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth + (selected ? AppSizes.s2 : AppSizes.s0)) * fullness;
      return Container(
        height: RiderLayout.chooseSpotFullnessBarHeight,
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(color: RiderColors.spotTrack, borderRadius: BorderRadius.circular(AppSizes.s3)),
        child: Container(
          width: width < RiderLayout.chooseSpotFullnessBarHeight ? RiderLayout.chooseSpotFullnessBarHeight : width,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppSizes.s3)),
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
    padding: const EdgeInsets.symmetric(horizontal: AppSizes.s14, vertical: AppSizes.s12),
    decoration: BoxDecoration(color: RiderColors.tipFill, borderRadius: BorderRadius.circular(RiderRadius.m)),
    child: Text(
      AppStrings.justFilledUpAnotherRiderGot(name),
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
      bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s16),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottom: [RiderButton(AppStrings.checkAgain, onPressed: onCheckAgain)],
      children: [
        RiderHomeHeader(greeting: greeting(now), name: ref.watch(riderFirstNameProvider)),
        const SizedBox(height: AppSizes.s56),
        const Center(
          child: RiderArtTile.medium(glyph: Icon(Icons.pin_drop_outlined, size: AppSizes.s32, color: RiderColors.brand)),
        ),
        const SizedBox(height: AppSizes.s20),
        Padding(
          padding: const EdgeInsets.only(left: AppSizes.s1_2),
          child: Text(
            AppStrings.noSpotFree,
            textAlign: TextAlign.center,
            style: RiderText.overlineSpaced1_2,
          ),
        ),
        const SizedBox(height: AppSizes.s8),
        Text(AppStrings.noSpotAvailableRightNow, textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: AppSizes.s8),
        Text(
          AppStrings.everySpotNearYouHasA,
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
      ],
    );
  }
}
