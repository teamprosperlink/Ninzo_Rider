import 'package:flutter/material.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Onboard 07: the session ended on its own (another phone, timeout, or
/// "Keep me signed in" was off).
class SignedOutView extends StatelessWidget {
  const SignedOutView({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return RiderArtPage(
      art: const RiderArtTile(icon: Icons.lock_outline_rounded, iconColor: RiderColors.white),
      overline: AppStrings.sessionEnded,
      title: AppStrings.youVeBeenSignedOut,
      body: AppStrings.youSignedInOnAnotherPhone,
      benefits: const [AppStrings.yourStockAndEarningsAreSafe, AppStrings.takesAbout20Seconds],
      actions: [RiderButton(AppStrings.signIn, onPressed: onSignIn)],
      actionsPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12),
    );
  }
}
