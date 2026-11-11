import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/online_status.dart';
import '../viewmodels/online_map_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Shift 33 "Want to keep riding?", 34 while adding.
class AddTimePage extends ConsumerWidget {
  const AddTimePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onlineMapViewModelProvider);
    final vm = ref.read(onlineMapViewModelProvider.notifier);
    return RiderArtPage(
      art: const RiderArtTile.medium(glyph: RiderPlusGlyph()),
      overline: AppStrings.keepRiding,
      title: AppStrings.wantToKeepRiding,
      body: AppStrings.addTimeAndOrdersKeepComing,
      padding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s72, AppSizes.s16, AppSizes.s16),
      actionsPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      content: Padding(
        padding: const EdgeInsets.only(top: AppSizes.s8),
        child: Column(
          children: [
            RiderChoiceChips<AddTimeOption>(
              options: AddTimeOption.values,
              selected: state.option,
              label: (o) => o.label,
              onSelected: state.adding ? null : vm.selectOption,
            ),
            const SizedBox(height: AppSizes.s16),
            Text(AppStrings.ifYouDonTAddTime, style: RiderText.caption),
          ],
        ),
      ),
      actions: [
        RiderButton(
          AppStrings.keepRiding2(state.option.label),
          onPressed: vm.addTime,
          loading: state.adding,
          loadingLabel: AppStrings.addingTime,
        ),
        RiderButton.ghost(AppStrings.letMyShiftEnd, onPressed: state.adding ? () {} : vm.letShiftEnd),
      ],
    );
  }
}
