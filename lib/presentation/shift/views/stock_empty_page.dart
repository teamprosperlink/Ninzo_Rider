import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/shift.dart';
import '../providers/shift_providers.dart';
import '../viewmodels/shift_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Shift 51 "Stock empty": Go online without stock on the scooter.
class StockEmptyPage extends ConsumerWidget {
  const StockEmptyPage({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(shiftFlowViewModelProvider.notifier);
    final busy = ref.watch(shiftFlowViewModelProvider.select((s) => s.busy));
    final now = watchShiftClock(ref);
    final hub = shift.hub.name;
    return RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s16),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottom: [
        RiderButton(AppStrings.navigateTo(hub), onPressed: vm.goToHub),
        RiderButton.ghost(AppStrings.requestHubToPrepare, onPressed: busy ? null : vm.askHubToPrepare),
      ],
      children: [
        RiderHomeHeader(greeting: greeting(now), name: ref.watch(riderFirstNameProvider), onAvatarTap: vm.openProfile),
        const SizedBox(height: AppSizes.s56),
        const Center(child: RiderArtTile.medium(icon: Icons.inventory_2_outlined)),
        const SizedBox(height: AppSizes.s20),
        Padding(
          padding: const EdgeInsets.only(left: AppSizes.s1_2),
          child: Text(AppStrings.stockNeeded, textAlign: TextAlign.center, style: RiderText.overlineSpaced1_2),
        ),
        const SizedBox(height: AppSizes.s8),
        Text(AppStrings.loadStockAtTheHub, textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: AppSizes.s8),
        Text(
          AppStrings.youReOfflineUntilYourScooter(hub),
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
      ],
    );
  }
}
