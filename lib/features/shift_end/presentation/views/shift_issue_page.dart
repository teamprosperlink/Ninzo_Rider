import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../domain/entities/shift_end.dart';
import '../viewmodels/shift_issue_view_model.dart';
import '../widgets/demo_shift_end_pills.dart';

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
        'Paused',
        Icons.pin_drop_outlined,
        'LOCATION OFF',
        'Turn on location to keep riding',
        'Turn on location and orders start again right away. We use it to match you with nearby orders.',
      ),
      ShiftIssue.phoneTimeWrong => (
        'Offline',
        Icons.pin_drop_outlined,
        'CHECK PHONE TIME',
        'Let’s fix your phone’s time',
        'Set date and time to automatic so every delivery is recorded correctly.',
      ),
      ShiftIssue.shiftAlreadyOpen => (
        'Offline',
        Icons.phone_android_outlined,
        'SHIFT ALREADY OPEN',
        'You’re riding on another phone',
        'Your shift is open on another phone. Continue here and that phone will be signed out.',
      ),
      ShiftIssue.noInternet => (
        'Offline',
        Icons.cloud_off_outlined,
        'NO INTERNET',
        'Let’s get you online',
        'Turn on mobile data or Wi-Fi, then tap Try again to start riding.',
      ),
    };
    final noInternet = issue == ShiftIssue.noInternet;
    final page = RiderScaffold(
      showBack: false,
      // 4px wider than the frame's text box, which Flutter's text just overruns
      // on Shift 42; nothing else in the frames reaches that far.
      bodyPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottom: switch (issue) {
        ShiftIssue.locationOff => [
          RiderButton('Open settings', onPressed: vm.openSettings),
          RiderButton.ghost('Go offline', onPressed: vm.goOffline),
        ],
        ShiftIssue.phoneTimeWrong => [
          RiderButton('Open date settings', onPressed: vm.openDateSettings),
          RiderButton.ghost('Check again', onPressed: vm.checkAgain),
        ],
        ShiftIssue.shiftAlreadyOpen => [
          RiderButton('Continue on this phone', onPressed: vm.continueHere),
          RiderButton.ghost('Cancel', onPressed: vm.backHome),
        ],
        ShiftIssue.noInternet => [RiderButton('Try again', onPressed: vm.backHome)],
      },
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: RiderHomeHeader(
            greeting: greeting(now),
            name: ref.watch(riderFirstNameProvider),
            status: RiderStatusPill.offline(label: pill),
          ),
        ),
        const SizedBox(height: 56),
        Center(
          child: RiderArtTile.medium(
            glyph: Icon(icon, size: 28, color: noInternet ? RiderColors.error : RiderColors.brand),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.only(left: 1.2),
          child: Text(
            overline,
            textAlign: TextAlign.center,
            style: RiderText.overline.copyWith(letterSpacing: 1.2, color: noInternet ? RiderColors.error : null),
          ),
        ),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: RiderText.h4),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
      ],
    );
    if (!kDemoMode || !noInternet) return page;
    return Stack(children: [page, const DemoSignalBackPill()]);
  }
}
