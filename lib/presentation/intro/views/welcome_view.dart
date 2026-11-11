import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_numbers.dart';

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
                      const SizedBox(height: AppSizes.s22),
                      const Center(child: _Hero()),
                      const SizedBox(height: AppSizes.s6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppStrings.deliverHotFoodIn90Seconds, style: RiderText.displayXl.copyWith(color: white)),
                            const SizedBox(height: AppSizes.s12),
                            Text(
                              AppStrings.waitAtYourSpotWithFood,
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
                padding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s16, AppSizes.s16, AppSizes.s16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RiderButton(AppStrings.signIn, onPressed: onSignIn, style: RiderButtonStyle.inverse),
                    const SizedBox(height: AppSizes.s12),
                    RiderButton(AppStrings.newRiderRegister, onPressed: onRegister, style: RiderButtonStyle.inverseOutline),
                    const SizedBox(height: AppSizes.s12),
                    Text(
                      AppStrings.byContinuingYouAgreeToOur,
                      textAlign: TextAlign.center,
                      style: RiderText.caption.copyWith(color: white.withValues(alpha: AppOpacity.o0_7)),
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
      width: AppSizes.s360,
      height: AppSizes.s360,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: DecoratedBox(decoration: glow(AppOpacity.o0_06))),
          Positioned(left: AppSizes.s35, top: AppSizes.s35, width: AppSizes.s290, height: AppSizes.s290, child: DecoratedBox(decoration: glow(AppOpacity.o0_07))),
          Positioned(
            left: AppSizes.s72,
            top: AppSizes.s72,
            width: AppSizes.s216,
            height: AppSizes.s216,
            child: Image.asset(AppAssets.welcomeHero, width: AppSizes.s216, height: AppSizes.s216),
          ),
          Positioned(
            left: AppSizes.s72,
            width: AppSizes.s216,
            top: AppSizes.s168,
            child: Column(
              children: [
                Text(
                  AppStrings.heroPhoto,
                  textAlign: TextAlign.center,
                  style: RiderText.overlineSpaced1_4.copyWith(color: RiderColors.white),
                ),
                const SizedBox(height: AppSizes.s4),
                Text(
                  AppStrings.riderScooterBox,
                  textAlign: TextAlign.center,
                  style: RiderText.caption.copyWith(color: RiderColors.white.withValues(alpha: AppOpacity.o0_75)),
                ),
              ],
            ),
          ),
          const Positioned(left: AppSizes.s196, top: AppSizes.s50, child: _Chip(AppStrings.hotIn90Sec)),
          const Positioned(left: AppSizes.s30, top: AppSizes.s260, child: _Chip(AppStrings.sealedFresh)),
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
      padding: const EdgeInsets.fromLTRB(AppSizes.s12, AppSizes.s8, AppSizes.s16, AppSizes.s8),
      decoration: BoxDecoration(
        color: RiderColors.white.withValues(alpha: AppOpacity.o0_853),
        borderRadius: BorderRadius.circular(RiderRadius.pill),
        boxShadow: RiderLayout.brand30Shadow8x16_5,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSizes.s8,
            height: AppSizes.s8,
            decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSizes.s8),
          Text(label, style: RiderText.labelLarge),
        ],
      ),
    );
  }
}
