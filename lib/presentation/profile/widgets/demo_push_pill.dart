import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../online/widgets/demo_online_controls.dart';
import '../viewmodels/profile_view_models.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/demo_data.dart';
import '../../../core/constants/app_keys.dart';

/// Demo mode only, not part of the design: on Profile 01, shows the phone's
/// real notification for Notification 01–04, one after another.
class DemoPushPill extends ConsumerStatefulWidget {
  const DemoPushPill({super.key});

  @override
  ConsumerState<DemoPushPill> createState() => _DemoPushPillState();
}

class _DemoPushPillState extends ConsumerState<DemoPushPill> {
  // Survives leaving the menu.
  static var _next = 0;

  @override
  Widget build(BuildContext context) {
    final (push, label) = DemoData.pushes[_next];
    return Positioned(
      right: AppSizes.s16,
      top: AppSizes.s104,
      child: DemoPill(
        key: const Key(AppKeys.demoProfilePush),
        label: AppStrings.demoPush(label),
        onTap: () {
          ref.read(profileMenuViewModelProvider.notifier).demoPush(push);
          setState(() => _next = (_next + 1) % DemoData.pushes.length);
        },
      ),
    );
  }
}
