import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/online_status.dart';
import '../viewmodels/online_map_view_model.dart';

/// Shift 33 "Want to keep riding?", 34 while adding.
class AddTimePage extends ConsumerWidget {
  const AddTimePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onlineMapViewModelProvider);
    final vm = ref.read(onlineMapViewModelProvider.notifier);
    return RiderArtPage(
      art: const RiderArtTile.medium(glyph: RiderPlusGlyph()),
      overline: 'Keep riding',
      title: 'Want to keep riding?',
      body: 'Add time and orders keep coming to you. Choose how long, up to 4 hours.',
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            RiderChoiceChips<AddTimeOption>(
              options: AddTimeOption.values,
              selected: state.option,
              label: (o) => o.label,
              onSelected: state.adding ? null : vm.selectOption,
            ),
            const SizedBox(height: 16),
            Text('If you don’t add time, your shift ends as planned.', style: RiderText.caption),
          ],
        ),
      ),
      actions: [
        RiderButton(
          'Keep riding · ${state.option.label}',
          onPressed: vm.addTime,
          loading: state.adding,
          loadingLabel: 'Adding time…',
        ),
        RiderButton.ghost('Let my shift end', onPressed: state.adding ? () {} : vm.letShiftEnd),
      ],
    );
  }
}
