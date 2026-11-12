import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/pre_shift_check.dart';
import '../../../domain/entities/shift.dart';
import '../viewmodels/checklist_view_model.dart';
import '../viewmodels/shift_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_keys.dart';

/// "Before you start" (Shift 10 none ticked, 11 some, 12 all). Go to hub
/// unlocks when every item is ticked.
class ChecklistPage extends ConsumerWidget {
  const ChecklistPage({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checklistViewModelProvider);
    final vm = ref.read(checklistViewModelProvider.notifier);

    return RiderScaffold(
      title: AppStrings.beforeYouStart,
      onBack: ref.read(shiftFlowViewModelProvider.notifier).home,
      headerPadding: RiderHeader.flowPadding,
      backSize: AppSizes.s48,
      backBordered: true,
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottomNote: state.allTicked ? AppStrings.allSetHeadToTheHub : AppStrings.completeAllChecksToContinue,
      bottom: [RiderButton(AppStrings.goToHub, onPressed: state.allTicked ? vm.goToHub : null, loading: state.busy)],
      children: [
        Text(
          AppStrings.quickChecksKeepYouAndYour,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderPanel(
          gap: AppSizes.s16,
          children: [
            for (final check in PreShiftCheck.values)
              RiderCheckRow(
                key: Key(AppKeys.check(check.name)),
                title: check.title,
                subtitle: _hint(check),
                checked: state.ticked.contains(check),
                onTap: () => vm.toggle(check),
              ),
          ],
        ),
      ],
    );
  }

  /// The item's line, from the rider API; the battery items say their level
  /// from the zone's settings and the scooter's telemetry. The scooter's
  /// charge shows only when it's enough, as in the frames.
  String? _hint(PreShiftCheck check) => switch (check.kind) {
    CheckKind.phoneBattery => AppStrings.atLeastBattery(PreShiftCheck.minPhoneBattery),
    CheckKind.scooterBattery => shift.scooter.batteryOk ? AppStrings.showsEnoughForTheShift(shift.scooter.batteryPercent) : null,
    _ => check.hint,
  };

}
