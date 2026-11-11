import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../shift/providers/shift_providers.dart';
import '../../../domain/entities/shift_end.dart';
import '../viewmodels/shift_issue_view_model.dart';
import '../widgets/demo_shift_end_pills.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Shift 41, 42, 54, 55: what stops the rider, one screen by [ShiftIssue].
class ShiftIssuePage extends ConsumerWidget {
  const ShiftIssuePage({super.key, required this.issue});

  final ShiftIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    final vm = ref.read(shiftIssueViewModelProvider.notifier);
    final (pill, icon, overline, title, body) = switch (issue) {
      ShiftIssue.locationOff => (
        AppStrings.paused,
        Icons.pin_drop_outlined,
        AppStrings.locationOff,
        AppStrings.turnOnLocationToKeepRiding,
        AppStrings.turnOnLocationAndOrdersStart,
      ),
      ShiftIssue.phoneTimeWrong => (
        AppStrings.offline,
        Icons.pin_drop_outlined,
        AppStrings.checkPhoneTime,
        AppStrings.letSFixYourPhoneS,
        AppStrings.setDateAndTimeToAutomatic,
      ),
      ShiftIssue.shiftAlreadyOpen => (
        AppStrings.offline,
        Icons.phone_android_outlined,
        AppStrings.shiftAlreadyOpen,
        AppStrings.youReRidingOnAnotherPhone,
        AppStrings.yourShiftIsOpenOnAnother,
      ),
      ShiftIssue.noInternet => (
        AppStrings.offline,
        Icons.cloud_off_outlined,
        AppStrings.noInternet,
        AppStrings.letSGetYouOnline,
        AppStrings.turnOnMobileDataOrWi,
      ),
    };
    final noInternet = issue == ShiftIssue.noInternet;
    final page = RiderScaffold(
      showBack: false,
      // 4px wider than the frame's text box, which Flutter's text just overruns
      // on Shift 42; nothing else in the frames reaches that far.
      bodyPadding: const EdgeInsets.fromLTRB(AppSizes.s14, AppSizes.s0, AppSizes.s14, AppSizes.s16),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
      bottom: switch (issue) {
        ShiftIssue.locationOff => [
          RiderButton(AppStrings.openSettings, onPressed: vm.openSettings),
          RiderButton.ghost(AppStrings.goOffline, onPressed: vm.goOffline),
        ],
        ShiftIssue.phoneTimeWrong => [
          RiderButton(AppStrings.openDateSettings, onPressed: vm.openDateSettings),
          RiderButton.ghost(AppStrings.checkAgain, onPressed: vm.checkAgain),
        ],
        ShiftIssue.shiftAlreadyOpen => [
          RiderButton(AppStrings.continueOnThisPhone, onPressed: vm.continueHere),
          RiderButton.ghost(AppStrings.cancel, onPressed: vm.backHome),
        ],
        ShiftIssue.noInternet => [RiderButton(AppStrings.tryAgain, onPressed: vm.backHome)],
      },
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.s2),
          child: RiderHomeHeader(
            greeting: greeting(now),
            name: ref.watch(riderFirstNameProvider),
            status: RiderStatusPill.offline(label: pill),
          ),
        ),
        const SizedBox(height: AppSizes.s56),
        Center(
          child: RiderArtTile.medium(
            glyph: Icon(icon, size: AppSizes.s28, color: noInternet ? RiderColors.error : RiderColors.brand),
          ),
        ),
        const SizedBox(height: AppSizes.s20),
        Padding(
          padding: const EdgeInsets.only(left: AppSizes.s1_2),
          child: Text(
            overline,
            textAlign: TextAlign.center,
            style: RiderText.overlineSpaced1_2.copyWith(color: noInternet ? RiderColors.error : null),
          ),
        ),
        const SizedBox(height: AppSizes.s8),
        Text(title, textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: AppSizes.s8),
        Text(body, textAlign: TextAlign.center, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
      ],
    );
    if (!kDemoControls || !noInternet) return page;
    return Stack(children: [page, const DemoSignalBackPill()]);
  }
}
