import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/rider/rider_ui.dart';

/// Onboard 02: hero, pitch, "Sign in" and "New rider? Register".
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key, required this.onSignIn, required this.onRegister});

  final VoidCallback onSignIn;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final white = RiderColors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarLight,
      child: Scaffold(
        backgroundColor: RiderColors.brand,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 22),
                      const Center(child: _Hero()),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Deliver hot food in 90 seconds', style: RiderText.displayXl.copyWith(color: white)),
                            const SizedBox(height: 12),
                            Text(
                              'Wait at your spot with food already on the scooter. Orders land seconds from the gate.',
                              style: RiderText.bodyMedium.copyWith(color: white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RiderButton('Sign in', onPressed: onSignIn, style: RiderButtonStyle.inverse),
                    const SizedBox(height: 12),
                    RiderButton('New rider? Register', onPressed: onRegister, style: RiderButtonStyle.inverseOutline),
                    const SizedBox(height: 12),
                    Text(
                      'By continuing you agree to our Terms & Privacy Policy',
                      textAlign: TextAlign.center,
                      style: RiderText.caption.copyWith(color: white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glow rings, hero photo placeholder and the two chips (360 × 360).
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    BoxDecoration glow(double alpha) => BoxDecoration(shape: BoxShape.circle, color: RiderColors.white.withValues(alpha: alpha));
    return SizedBox(
      width: 360,
      height: 360,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: DecoratedBox(decoration: glow(0.06))),
          Positioned(left: 35, top: 35, width: 290, height: 290, child: DecoratedBox(decoration: glow(0.07))),
          Positioned(
            left: 72,
            top: 72,
            width: 216,
            height: 216,
            child: Image.asset('assets/images/welcome_hero.png', width: 216, height: 216),
          ),
          Positioned(
            left: 72,
            width: 216,
            top: 168,
            child: Column(
              children: [
                Text(
                  'HERO PHOTO',
                  textAlign: TextAlign.center,
                  style: RiderText.overline.copyWith(color: RiderColors.white, letterSpacing: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  'rider + scooter box',
                  textAlign: TextAlign.center,
                  style: RiderText.caption.copyWith(color: RiderColors.white),
                ),
              ],
            ),
          ),
          const Positioned(left: 196, top: 50, child: _Chip('Hot in 90 sec')),
          const Positioned(left: 30, top: 260, child: _Chip('Sealed & fresh')),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      decoration: BoxDecoration(
        color: RiderColors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(RiderRadius.pill),
        boxShadow: const [BoxShadow(color: RiderColors.brand30, offset: Offset(0, 8), blurRadius: 16.5)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: RiderText.labelLarge),
        ],
      ),
    );
  }
}
