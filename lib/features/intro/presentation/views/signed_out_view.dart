import 'package:flutter/material.dart';

import '../../../../core/widgets/rider/rider_ui.dart';

/// Onboard 07: the session ended on its own (another phone, timeout, or
/// "Keep me signed in" was off).
class SignedOutView extends StatelessWidget {
  const SignedOutView({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return RiderArtPage(
      art: const RiderArtTile(icon: Icons.lock_outline_rounded, iconColor: RiderColors.white),
      overline: 'Session ended',
      title: 'You’ve been signed out',
      body: 'You signed in on another phone, or this session timed out. Sign in again and pick up where you left off.',
      benefits: const ['Your stock and earnings are safe', 'Takes about 20 seconds'],
      actions: [RiderButton('Sign in', onPressed: onSignIn)],
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    );
  }
}
