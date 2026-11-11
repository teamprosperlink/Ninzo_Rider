import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_sizes.dart';

/// Dark toast above the bottom bar: a green dot and a line (Stock 02, 12).
class RiderToast extends StatelessWidget {
  const RiderToast(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.s16),
    decoration: BoxDecoration(
      color: RiderColors.ink,
      borderRadius: BorderRadius.circular(RiderRadius.m),
      boxShadow: riderShadow,
    ),
    child: Row(
      children: [
        Container(
          width: AppSizes.s10,
          height: AppSizes.s10,
          decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: Text(message, style: RiderText.labelMedium.copyWith(color: RiderColors.white)),
        ),
      ],
    ),
  );
}

/// Amber card: info icon, title, grey line (Stock 04, 10, 11, 16).
class RiderWarningCard extends StatelessWidget {
  const RiderWarningCard({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.s12),
    decoration: BoxDecoration(color: RiderColors.warningFill, borderRadius: BorderRadius.circular(RiderRadius.m)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: AppSizes.s24, color: RiderColors.ink),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: RiderText.labelLarge),
              const SizedBox(height: AppSizes.s2),
              Text(message, style: RiderText.caption),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Amber strip with one line: over the order map (Navigate 01–03, on
/// [RiderColors.warningBanner]), or on the screen (Arrival 02).
class RiderWarningStrip extends StatelessWidget {
  const RiderWarningStrip(this.message, {super.key, this.color = RiderColors.warningBanner});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s12),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(RiderRadius.m)),
    child: Text(message, style: RiderText.labelMedium.copyWith(color: RiderColors.warningText)),
  );
}

/// Red banner with a short explanation (Stock 07, 08).
class RiderErrorBanner extends StatelessWidget {
  const RiderErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s12),
    decoration: BoxDecoration(color: RiderColors.errorFill, borderRadius: BorderRadius.circular(RiderRadius.m)),
    child: Text(message, style: RiderText.labelMedium.copyWith(color: RiderColors.errorPressed)),
  );
}

/// Pill with minus, the count, and a green plus (Stock 05).
class RiderQuantityStepper extends StatelessWidget {
  const RiderQuantityStepper({super.key, required this.value, this.onMinus, this.onPlus});

  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.s4),
    decoration: BoxDecoration(color: RiderColors.stepperTrack, borderRadius: BorderRadius.circular(RiderRadius.pill)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: AppStrings.fewer,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMinus,
            child: SizedBox.square(
              dimension: AppSizes.s40,
              child: Center(
                child: Container(
                  width: AppSizes.s12,
                  height: AppSizes.s2,
                  decoration: BoxDecoration(
                    color: RiderColors.ink,
                    borderRadius: BorderRadius.circular(RiderRadius.pill),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.s12),
        Text('$value', style: RiderText.labelLarge),
        const SizedBox(width: AppSizes.s12),
        Semantics(
          button: true,
          label: AppStrings.more,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPlus,
            child: Container(
              width: AppSizes.s40,
              height: AppSizes.s40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
              child: const SizedBox.square(
                dimension: AppSizes.s12,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(width: AppSizes.s12, height: AppSizes.s2, child: ColoredBox(color: RiderColors.white)),
                    SizedBox(width: AppSizes.s2, height: AppSizes.s12, child: ColoredBox(color: RiderColors.white)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Tick in pale green circles: 112px with an inner 72px (Stock 06), or a
/// plain 72px with a small tick (Stock 13, 14).
class RiderTickHalo extends StatelessWidget {
  const RiderTickHalo({
    super.key,
    this.outer = RiderColors.haloOuter,
    this.inner = RiderColors.haloInner,
    this.innerSize = AppSizes.s72,
    this.iconSize = AppSizes.s32,
  }) : small = false;

  const RiderTickHalo.small({super.key})
    : small = true,
      outer = RiderColors.haloOuter,
      inner = RiderColors.haloInner,
      innerSize = AppSizes.s72,
      iconSize = AppSizes.s32;

  final bool small;
  final Color outer;
  final Color inner;
  final double innerSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (small) {
      return Container(
        width: AppSizes.s72,
        height: AppSizes.s72,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: RiderColors.haloOuter, shape: BoxShape.circle),
        child: const Icon(Icons.check, size: AppSizes.s18, color: RiderColors.brand),
      );
    }
    return Container(
      width: AppSizes.s112,
      height: AppSizes.s112,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: outer, shape: BoxShape.circle),
      child: Container(
        width: innerSize,
        height: innerSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: inner, shape: BoxShape.circle),
        child: Icon(Icons.check, size: iconSize, color: RiderColors.white),
      ),
    );
  }
}

/// 22px green circle with a bold white tick (a loaded item, Stock 03, 15, 16).
class RiderTickBadge extends StatelessWidget {
  const RiderTickBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: AppSizes.s22,
    height: AppSizes.s22,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
    child: const SizedBox.square(dimension: AppSizes.s16, child: CustomPaint(painter: _TickPainter())),
  );
}

class _TickPainter extends CustomPainter {
  const _TickPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(AppSizes.s3_2, AppSizes.s8_4)
        ..lineTo(AppSizes.s6_6, AppSizes.s11_8)
        ..lineTo(AppSizes.s12_8, AppSizes.s4_6),
      Paint()
        ..color = RiderColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.s2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) => false;
}
