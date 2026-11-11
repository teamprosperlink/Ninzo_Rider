import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../injection_container.dart';
import '../../../domain/entities/spot_option.dart';
import '../viewmodels/choose_spot_view_model.dart';
import 'demo_online_controls.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_keys.dart';

/// Demo mode only, not part of the design: on Home with the stock loaded, the
/// way into Shift 13. The flow map has no arrow into Choose a spot.
class DemoChooseSpotPill extends ConsumerWidget {
  const DemoChooseSpotPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Positioned(
    right: AppSizes.s16,
    bottom: AppSizes.s120,
    child: DemoPill(
      key: const Key(AppKeys.demoChooseSpot),
      label: AppStrings.demoChooseASpot,
      onTap: () {
        ref.read(demoSpotChoiceProvider)?.reset();
        ref.read(chooseSpotViewModelProvider.notifier).open();
      },
    ),
  );
}

/// Demo mode only: plays the backend on Shift 13–18.
class DemoSpotStatePill extends ConsumerWidget {
  const DemoSpotStatePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chooseSpotViewModelProvider);
    final vm = ref.read(chooseSpotViewModelProvider.notifier);
    final demo = ref.read(demoSpotChoiceProvider);
    if (demo == null) return const SizedBox.shrink();

    /// The spot that fills up: the selected one, else one with a rider already.
    SpotOption fillTarget() =>
        state.selected ??
        state.spots.firstWhere((s) => s.taken > 0 && !s.isFull, orElse: () => state.spots.firstWhere((s) => !s.isFull));

    final (String? label, VoidCallback? onTap) = switch (state.stage) {
      ChooseSpotStage.finding => (AppStrings.noSpotAvailable, () => demo.noneFree = true),
      ChooseSpotStage.choosing => (
        AppStrings.spotIsFull,
        () {
          final spot = fillTarget();
          demo.fill(spot.name);
          vm.spotFilled(spot);
        },
      ),
      // The confirm under way finds the spot gone.
      ChooseSpotStage.confirming => (AppStrings.spotIsFull, () => demo.fill(state.selected!.name)),
      ChooseSpotStage.noSpot => (AppStrings.spotOpens, demo.reset),
      ChooseSpotStage.spotFull => (null, null),
    };
    if (label == null) return const SizedBox.shrink();
    return Positioned(
      right: AppSizes.s16,
      bottom: AppSizes.s180,
      child: DemoPill(key: const Key(AppKeys.demoSpotState), label: AppStrings.demo(label), onTap: onTap!),
    );
  }
}
