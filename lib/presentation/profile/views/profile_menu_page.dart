import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../viewmodels/profile_view_models.dart';
import '../widgets/demo_push_pill.dart';
import '../widgets/profile_widgets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Profile 01 "Menu", and Profile 03: Home's header under a scrim with the
/// sheet, as Shift 46–49 draw theirs.
class ProfileMenuPage extends ConsumerWidget {
  const ProfileMenuPage({super.key, required this.shift});

  /// Null on a day off.
  final Shift? shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirming = ref.watch(profileMenuViewModelProvider);
    return confirming ? _LogOutSheet(shift: shift) : _Menu(shift: shift);
  }
}

class _Menu extends ConsumerWidget {
  const _Menu({required this.shift});

  final Shift? shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = ref.watch(profileHeaderProvider);
    final vm = ref.read(profileMenuViewModelProvider.notifier);
    return Stack(
      children: [
        ProfileScaffold(
          title: AppStrings.profile,
          onBack: vm.back,
          children: [
            ProfileHeader(name: header.name, role: header.role),
            const SizedBox(height: AppSizes.s16),
            ProfileCard(
              rows: [
                _MenuRow(
                  icon: Icons.account_circle_outlined,
                  label: AppStrings.yourProfile,
                  onTap: () => vm.open(ShiftScreen.profileDetails),
                ),
                _MenuRow(
                  icon: Icons.pin_drop_outlined,
                  label: AppStrings.mySpot2(shift?.spot.name ?? ''),
                  onTap: () => vm.open(ShiftScreen.profileSpot),
                ),
                _MenuRow(
                  icon: Icons.notifications_none,
                  label: AppStrings.notifications,
                  onTap: () => vm.open(ShiftScreen.profileNotifications),
                ),
                _MenuRow(icon: Icons.history, label: AppStrings.myShifts, onTap: () => vm.open(ShiftScreen.profileShifts)),
                _MenuRow(
                  icon: Icons.insert_drive_file_outlined,
                  label: AppStrings.documents,
                  onTap: () => vm.open(ShiftScreen.profileDocuments),
                ),
                _MenuRow(icon: Icons.help_outline, label: AppStrings.helpCentre, onTap: () => vm.open(ShiftScreen.profileHelp)),
                // No arrow or frame on the flow map.
                const _MenuRow(icon: Icons.shield_outlined, label: AppStrings.privacyPolicy),
              ],
            ),
            const SizedBox(height: AppSizes.s16),
            ProfileCard(
              rows: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: vm.askLogOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s12),
                    child: Row(
                      children: [
                        const RiderIconTile(Icons.logout, color: RiderColors.error, tint: RiderColors.errorTile),
                        const SizedBox(width: AppSizes.s12),
                        Text(AppStrings.logOut, style: RiderText.labelLarge.copyWith(color: RiderColors.error)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (kDemoControls) const DemoPushPill(),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: SizedBox(
      height: AppSizes.s56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
        child: Row(
          children: [
            RiderIconTile(icon, tint: RiderColors.nudgeTile),
            const SizedBox(width: AppSizes.s12),
            Expanded(child: Text(label, style: RiderText.labelLarge)),
            const Icon(Icons.chevron_right, size: AppSizes.s20, color: RiderColors.grey),
          ],
        ),
      ),
    ),
  );
}

class _LogOutSheet extends ConsumerWidget {
  const _LogOutSheet({required this.shift});

  final Shift? shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    final vm = ref.read(profileMenuViewModelProvider.notifier);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarDark,
      child: Scaffold(
        backgroundColor: RiderColors.screen,
        body: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
                child: SizedBox(
                  height: AppSizes.s46,
                  child: RiderHomeHeader(
                    greeting: greeting(now),
                    name: ref.watch(riderFirstNameProvider),
                    status: shift?.phase == ShiftPhase.online
                        ? const RiderStatusPill(AppStrings.online, tint: RiderColors.headerUnderDialog)
                        : const RiderStatusPill.offline(),
                    avatarTint: RiderColors.headerUnderDialog,
                  ),
                ),
              ),
            ),
            const Positioned.fill(child: ColoredBox(color: RiderColors.scrim)),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s24, AppSizes.s16, AppSizes.s12 + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                  color: RiderColors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(RiderRadius.sheet)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(AppStrings.logOut2, style: RiderText.h4),
                    const SizedBox(height: AppSizes.s8),
                    Text(
                      AppStrings.youLlNeedYourMobileNumber,
                      style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                    ),
                    const SizedBox(height: AppSizes.s16),
                    RiderButton(AppStrings.stayLoggedIn, onPressed: vm.stayLoggedIn),
                    const SizedBox(height: AppSizes.s16),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: vm.logOut,
                      child: SizedBox(
                        height: AppSizes.s48,
                        child: Center(
                          child: RiderHugText(AppStrings.logOut, style: RiderText.button.copyWith(color: RiderColors.error)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
