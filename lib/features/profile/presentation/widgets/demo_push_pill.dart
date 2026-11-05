import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../online/presentation/widgets/demo_online_controls.dart';
import '../../../shift/domain/entities/shift_push.dart';
import '../viewmodels/profile_view_models.dart';

/// Demo mode only, not part of the design: on Profile 01, shows the phone's
/// real notification for Notification 01–04, one after another.
class DemoPushPill extends ConsumerStatefulWidget {
  const DemoPushPill({super.key});

  @override
  ConsumerState<DemoPushPill> createState() => _DemoPushPillState();
}

class _DemoPushPillState extends ConsumerState<DemoPushPill> {
  static const _pushes = [
    (ShiftPush.spotAssigned, 'Spot assigned'),
    (ShiftPush.shiftEndingSoon, 'Shift ending'),
    (ShiftPush.ordersWaiting, 'Orders waiting'),
    (ShiftPush.awayFromSpot, 'Away from spot'),
  ];

  // Survives leaving the menu.
  static var _next = 0;

  @override
  Widget build(BuildContext context) {
    final (push, label) = _pushes[_next];
    return Positioned(
      right: 16,
      top: 104,
      child: DemoPill(
        key: const Key('demo_profile_push'),
        label: 'Demo: Push $label',
        onTap: () {
          ref.read(profileMenuViewModelProvider.notifier).demoPush(push);
          setState(() => _next = (_next + 1) % _pushes.length);
        },
      ),
    );
  }
}
