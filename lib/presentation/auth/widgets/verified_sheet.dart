import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Login 09: blurred scrim, close button, and the floating "Verified!" sheet.
class VerifiedSheet extends StatelessWidget {
  const VerifiedSheet({super.key, required this.message, required this.onDone});

  final String message;

  /// "Start shift" and the close button.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: AppSizes.s6, sigmaY: AppSizes.s6),
              child: const ColoredBox(color: RiderColors.sheetScrim),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.only(bottom: AppSizes.s12),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.s10),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: AppStrings.close,
                      // Just the white circle with its soft shadow: no square
                      // Material or ink layer behind it.
                      child: GestureDetector(
                        onTap: onDone,
                        child: Container(
                          width: AppSizes.s44,
                          height: AppSizes.s44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: RiderColors.white,
                            boxShadow: RiderLayout.shadowShadow4x11_3,
                          ),
                          child: const Icon(Icons.close, size: AppSizes.s24, color: RiderColors.ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.s12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSizes.s12),
                      padding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s28, AppSizes.s16, AppSizes.s16),
                      decoration: BoxDecoration(
                        color: RiderColors.white,
                        borderRadius: BorderRadius.circular(RiderRadius.sheet),
                        boxShadow: RiderLayout.sheetShadowShadow16x40_7,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(AppStrings.verified2, textAlign: TextAlign.center, style: RiderText.h4),
                          const SizedBox(height: AppSizes.s12),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                          ),
                          const SizedBox(height: AppSizes.s12),
                          const _VerifiedIllustration(),
                          const SizedBox(height: AppSizes.s12),
                          RiderButton(AppStrings.startShift, onPressed: onDone),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder art from the design ("Illustration (replace)"): a phone card
/// with a green tick on a pale green panel.
class _VerifiedIllustration extends StatelessWidget {
  const _VerifiedIllustration();

  @override
  Widget build(BuildContext context) {
    Widget line(double w, double h, Color c, double r) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r)),
    );
    return Container(
      height: AppSizes.s176,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.s24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [RiderColors.verifiedGradientStart, RiderColors.verifiedGradientEnd],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final cardLeft = (box.maxWidth - AppSizes.s132) / 2;
          return Stack(
            children: [
              Positioned(left: -AppSizes.s40, top: AppSizes.s70, child: _circle(AppSizes.s170)),
              Positioned(left: cardLeft + AppSizes.s114, top: -AppSizes.s40, child: _circle(AppSizes.s120)),
              Positioned(
                left: cardLeft,
                top: AppSizes.s44,
                child: Container(
                  width: AppSizes.s132,
                  height: AppSizes.s92,
                  padding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s18, AppSizes.s16, AppSizes.s0),
                  decoration: BoxDecoration(
                    color: RiderColors.white,
                    borderRadius: BorderRadius.circular(RiderRadius.card),
                    boxShadow: RiderLayout.brand20Shadow12x23_4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(AppSizes.s70, AppSizes.s8, RiderColors.track, RiderRadius.pill),
                      const SizedBox(height: AppSizes.s8),
                      line(AppSizes.s46, AppSizes.s8, RiderColors.track, RiderRadius.pill),
                      const SizedBox(height: AppSizes.s14),
                      line(AppSizes.s100, AppSizes.s14, RiderColors.brand12, AppSizes.s4),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: cardLeft + AppSizes.s112,
                top: AppSizes.s26,
                child: Container(
                  width: AppSizes.s44,
                  height: AppSizes.s44,
                  decoration: BoxDecoration(
                    color: RiderColors.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: RiderColors.white, width: AppSizes.s3),
                    boxShadow: RiderLayout.brand30Shadow6x11_3,
                  ),
                  child: const Icon(Icons.check, size: AppSizes.s16, color: RiderColors.white),
                ),
              ),
              Positioned(
                left: AppSizes.s0,
                right: AppSizes.s0,
                top: AppSizes.s148,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSizes.s1_4),
                  child: Text(
                    AppStrings.illustration,
                    textAlign: TextAlign.center,
                    style: RiderText.overlineSpaced1_4.copyWith(color: RiderColors.ink),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _circle(double size) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(color: RiderColors.white, shape: BoxShape.circle),
  );
}
