import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/pre_shift_check.dart';
import '../../domain/entities/shift.dart';
import '../viewmodels/checklist_view_model.dart';
import '../viewmodels/shift_flow_view_model.dart';

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
      title: 'Before you start',
      onBack: ref.read(shiftFlowViewModelProvider.notifier).home,
      headerPadding: RiderHeader.flowPadding,
      backSize: 48,
      backBordered: true,
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottomNote: state.allTicked ? 'All set. Head to the hub for your stock.' : 'Complete all checks to continue',
      bottom: [RiderButton('Go to hub', onPressed: state.allTicked ? vm.goToHub : null, loading: state.busy)],
      children: [
        Text(
          'Quick checks keep you and your orders safe.',
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: 16),
        RiderPanel(
          gap: 16,
          children: [
            for (final check in PreShiftCheck.values)
              RiderCheckRow(
                key: Key('check_${check.name}'),
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

  /// The scooter's charge shows only when it's enough, as in the frames.
  String? _hint(PreShiftCheck check) => switch (check) {
    PreShiftCheck.helmet => 'Wear your helmet at all times',
    PreShiftCheck.phoneCharged => 'At least ${PreShiftCheck.minPhoneBattery}% battery',
    PreShiftCheck.scooterBattery =>
      shift.scooter.batteryOk && shift.scooter.batteryPercent != null
          ? 'Shows ${shift.scooter.batteryPercent}% – enough for the shift'
          : null,
    PreShiftCheck.location => 'Needed to match you with nearby orders',
    PreShiftCheck.insulatedBox => 'Clean, no leaks, lid closes firmly',
    PreShiftCheck.scooterClean => 'Box and seat wiped',
  };

}
