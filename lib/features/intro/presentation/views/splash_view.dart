import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/rider/rider_ui.dart';

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
                  for (final size in const [400.0, 300.0, 210.0])
                    Positioned(
                      left: (104 - size) / 2,
                      top: (104 - size) / 2,
                      width: size,
                      height: size,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: RiderColors.white.withValues(alpha: size == 210 ? 0.14 : 0.09)),
                        ),
                      ),
                    ),
                  const RiderLogoMark(),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Ninzo',
                style: RiderText.displayXl.copyWith(
                  color: RiderColors.white,
                  fontSize: 44,
                  height: 52 / 44,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 26, height: 1.5, color: RiderColors.white.withValues(alpha: 0.38)),
                  const SizedBox(width: 12),
                  Text(
                    'HOT FOOD. 90 SECONDS.',
                    style: RiderText.overline.copyWith(color: RiderColors.white, letterSpacing: 1.4),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 26, height: 1.5, color: RiderColors.white.withValues(alpha: 0.38)),
                ],
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
