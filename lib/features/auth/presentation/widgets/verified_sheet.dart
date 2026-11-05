import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/widgets/rider/rider_ui.dart';

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
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const ColoredBox(color: Color(0x380C0C0C)),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Close',
                      // Just the white circle with its soft shadow: no square
                      // Material or ink layer behind it.
                      child: GestureDetector(
                        onTap: onDone,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: RiderColors.white,
                            boxShadow: [BoxShadow(color: RiderColors.shadow, offset: Offset(0, 4), blurRadius: 11.3)],
                          ),
                          child: const Icon(Icons.close, size: 24, color: RiderColors.ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
                      decoration: BoxDecoration(
                        color: RiderColors.white,
                        borderRadius: BorderRadius.circular(RiderRadius.sheet),
                        boxShadow: const [BoxShadow(color: Color(0x330C0C0C), offset: Offset(0, 16), blurRadius: 40.7)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Verified!', textAlign: TextAlign.center, style: RiderText.h4),
                          const SizedBox(height: 12),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                          ),
                          const SizedBox(height: 12),
                          const _VerifiedIllustration(),
                          const SizedBox(height: 12),
                          RiderButton('Start shift', onPressed: onDone),
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
      height: 176,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F7E0), Color(0xFFC2EDC7)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final cardLeft = (box.maxWidth - 132) / 2;
          return Stack(
            children: [
              Positioned(left: -40, top: 70, child: _circle(170)),
              Positioned(left: cardLeft + 114, top: -40, child: _circle(120)),
              Positioned(
                left: cardLeft,
                top: 44,
                child: Container(
                  width: 132,
                  height: 92,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  decoration: BoxDecoration(
                    color: RiderColors.white,
                    borderRadius: BorderRadius.circular(RiderRadius.card),
                    boxShadow: const [BoxShadow(color: Color(0x33009600), offset: Offset(0, 12), blurRadius: 23.4)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      line(70, 8, const Color(0x140C0C0C), RiderRadius.pill),
                      const SizedBox(height: 8),
                      line(46, 8, const Color(0x140C0C0C), RiderRadius.pill),
                      const SizedBox(height: 14),
                      line(100, 14, const Color(0x1F009600), 4),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: cardLeft + 112,
                top: 26,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: RiderColors.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: RiderColors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x4D009600), offset: Offset(0, 6), blurRadius: 11.3)],
                  ),
                  child: const Icon(Icons.check, size: 16, color: RiderColors.white),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 148,
                child: Padding(
                  padding: const EdgeInsets.only(left: 1.4),
                  child: Text(
                    'ILLUSTRATION',
                    textAlign: TextAlign.center,
                    style: RiderText.overline.copyWith(color: RiderColors.ink, letterSpacing: 1.4),
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
