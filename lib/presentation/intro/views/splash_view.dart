import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

/// Onboard 01: green splash with the Ninzo lockup, shown while the app starts.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarLight,
      child: Scaffold(
        backgroundColor: RiderColors.brand,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // The lockup sits slightly above centre, as in the design.
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  for (final size in const [AppSizes.s400_0, AppSizes.s300_0, AppSizes.s210_0])
                    Positioned(
                      left: (AppSizes.s104 - size) / 2,
                      top: (AppSizes.s104 - size) / 2,
                      width: size,
                      height: size,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: RiderColors.white.withValues(alpha: size == AppSizes.s210 ? AppOpacity.o0_14 : AppOpacity.o0_09)),
                        ),
                      ),
                    ),
                  const RiderLogoMark(),
                ],
              ),
              const SizedBox(height: AppSizes.s20),
              Text(
                AppStrings.ninzo,
                style: RiderText.splashTitle,
              ),
              const SizedBox(height: AppSizes.s20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: AppSizes.s26, height: AppSizes.s1_5, color: RiderColors.white.withValues(alpha: AppOpacity.o0_38)),
                  const SizedBox(width: AppSizes.s12),
                  Text(
                    AppStrings.hotFood90Seconds,
                    style: RiderText.overlineSpaced1_4.copyWith(color: RiderColors.white),
                  ),
                  const SizedBox(width: AppSizes.s12),
                  Container(width: AppSizes.s26, height: AppSizes.s1_5, color: RiderColors.white.withValues(alpha: AppOpacity.o0_38)),
                ],
              ),
              const SizedBox(height: AppSizes.s18),
            ],
          ),
        ),
      ),
    );
  }
}
