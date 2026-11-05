import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/shift.dart';
import '../providers/shift_providers.dart';
import '../viewmodels/shift_flow_view_model.dart';

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
      bodyPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottom: [
        RiderButton('Navigate to $hub', onPressed: vm.goToHub),
        RiderButton.ghost('Request hub to prepare', onPressed: busy ? null : vm.askHubToPrepare),
      ],
      children: [
        RiderHomeHeader(greeting: greeting(now), name: ref.watch(riderFirstNameProvider), onAvatarTap: vm.openProfile),
        const SizedBox(height: 56),
        const Center(child: RiderArtTile.medium(icon: Icons.inventory_2_outlined)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 1.2),
          child: Text('STOCK NEEDED', textAlign: TextAlign.center, style: RiderText.overline.copyWith(letterSpacing: 1.2)),
        ),
        const SizedBox(height: 8),
        Text('Load stock at the hub', textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: 8),
        Text(
          'You’re offline until your scooter has stock. Go to $hub and load your items.',
          textAlign: TextAlign.center,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
      ],
    );
  }
}
