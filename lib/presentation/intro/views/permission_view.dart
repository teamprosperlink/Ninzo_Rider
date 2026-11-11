import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/app_permission.dart';
import '../viewmodels/intro_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

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
        overline: AppStrings.actionNeeded,
        overlineColor: RiderColors.error,
        title: AppStrings.turnOnLocationToGoOnline,
        body: AppStrings.locationIsOffOnThisPhone,
        benefits: const [AppStrings.settingsLocationNinzoRider, AppStrings.chooseWhileUsingTheApp],
        actions: [
          RiderButton(AppStrings.openSettings, onPressed: vm.openSettings),
          RiderButton.secondary(AppStrings.iVeTurnedItOn, onPressed: busy ? null : vm.turnedOn),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      );
    }

    final (icon, iconColor, title, body, benefits, allowLabel) = switch (state.permission) {
      AppPermission.location => (
        Icons.location_on_outlined,
        RiderColors.brand,
        AppStrings.allowLocationAccess,
        AppStrings.onlyWhileYouReOnlineTo,
        const [
          AppStrings.matchYouToOrdersNearYour,
          AppStrings.showTheCustomerYourLivePosition,
          AppStrings.confirmYouVeReachedTheGate,
        ],
        AppStrings.allowLocation,
      ),
      AppPermission.notifications => (
        Icons.notifications_none_rounded,
        RiderColors.white,
        AppStrings.turnOnNotifications,
        AppStrings.newOrdersRingHereWithoutThem,
        const [AppStrings.newOrderAssignedToYou, AppStrings.restockRequestsFromTheHub, AppStrings.shiftReminders],
        AppStrings.turnOnNotifications,
      ),
      AppPermission.camera => (
        Icons.flip_camera_ios_outlined,
        RiderColors.white,
        AppStrings.allowCameraAccess,
        AppStrings.neededToScanStockOnYour,
        const [AppStrings.scanItemsYouLoadAtThe, AppStrings.scanTheGateQrOnArrival, AppStrings.photosForDocumentVerification],
        AppStrings.allowCamera,
      ),
    };
    return RiderArtPage(
      steps: (state.step, AppPermission.values.length),
      art: RiderArtTile(icon: icon, iconColor: iconColor),
      overline: AppStrings.permissionOf(state.step, AppPermission.values.length),
      title: title,
      body: body,
      benefits: benefits,
      actions: [
        RiderButton(allowLabel, onPressed: busy ? null : vm.allow),
        RiderButton.ghost(AppStrings.notNow, onPressed: busy ? null : vm.notNow),
      ],
    );
  }
}
