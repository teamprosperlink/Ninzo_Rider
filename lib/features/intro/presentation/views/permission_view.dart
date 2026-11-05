import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/app_permission.dart';
import '../viewmodels/intro_flow_view_model.dart';

/// Onboard 03–06: the permission screen for the current [AppPermission]
/// ("Permission N of 3"), and location's "Turn on location to go online"
/// state when location was denied or is switched off.
class PermissionView extends ConsumerWidget {
  const PermissionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(introFlowProvider);
    final vm = ref.read(introFlowProvider.notifier);
    final busy = state.busy;

    if (state.locationOff) {
      return RiderArtPage(
        art: const RiderArtTile(
          icon: Icons.location_on_outlined,
          tone: RiderColors.error,
          innerColor: RiderColors.error,
          iconColor: RiderColors.brand,
        ),
        overline: 'Action needed',
        overlineColor: RiderColors.error,
        title: 'Turn on location to go online',
        body: 'Location is off on this phone. Open settings, choose “While using the app”, then come back.',
        benefits: const ['Settings → Location → Ninzo Rider', 'Choose “While using the app”'],
        actions: [
          RiderButton('Open settings', onPressed: vm.openSettings),
          RiderButton.secondary('I’ve turned it on', onPressed: busy ? null : vm.turnedOn),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      );
    }

    final (icon, iconColor, title, body, benefits, allowLabel) = switch (state.permission) {
      AppPermission.location => (
        Icons.location_on_outlined,
        RiderColors.brand,
        'Allow location access',
        'Only while you’re online — to match you to nearby orders and show customers where you are.',
        const [
          'Match you to orders near your spot',
          'Show the customer your live position',
          'Confirm you’ve reached the gate',
        ],
        'Allow location',
      ),
      AppPermission.notifications => (
        Icons.notifications_none_rounded,
        RiderColors.white,
        'Turn on notifications',
        'New orders ring here. Without them you can miss a 90-second order.',
        const ['New order assigned to you', 'Restock requests from the hub', 'Shift reminders'],
        'Turn on notifications',
      ),
      AppPermission.camera => (
        Icons.flip_camera_ios_outlined,
        RiderColors.white,
        'Allow camera access',
        'Needed to scan stock on your scooter and the gate QR when you arrive.',
        const ['Scan items you load at the hub', 'Scan the gate QR on arrival', 'Photos for document verification'],
        'Allow camera',
      ),
    };
    return RiderArtPage(
      steps: (state.step, AppPermission.values.length),
      art: RiderArtTile(icon: icon, iconColor: iconColor),
      overline: 'Permission ${state.step} of ${AppPermission.values.length}',
      title: title,
      body: body,
      benefits: benefits,
      actions: [
        RiderButton(allowLabel, onPressed: busy ? null : vm.allow),
        RiderButton.ghost('Not now', onPressed: busy ? null : vm.notNow),
      ],
    );
  }
}
