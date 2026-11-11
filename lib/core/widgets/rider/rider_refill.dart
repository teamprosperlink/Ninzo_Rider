import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'rider_text.dart';
import '../../constants/app_sizes.dart';
import '../../constants/app_numbers.dart';

/// Info icon, title and grey body on a soft fill (Refill 01, 02).
class RiderInfoBanner extends StatelessWidget {
  const RiderInfoBanner({super.key, required this.title, required this.message, required this.color});

  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.s16),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(RiderRadius.field)),
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
              Text(message, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Stats spread to the card's edges, each as wide as its text (Refill 01).
class RiderSpreadStats extends StatelessWidget {
  const RiderSpreadStats(this.stats, {super.key});

  /// (value, label) pairs.
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.s16),
    decoration: BoxDecoration(
      color: RiderColors.white,
      borderRadius: BorderRadius.circular(RiderRadius.card),
      border: Border.all(color: RiderColors.hairline),
      boxShadow: riderShadow,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (value, label) in stats)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RiderHugText(value, style: RiderText.subheadingMedium),
              const SizedBox(height: AppSizes.s2),
              RiderHugText(label, style: RiderText.caption),
            ],
          ),
      ],
    ),
  );
}

/// The white nudge card over the main map (Shift 36, 39): a spot tile, title,
/// grey body and its buttons.
class RiderNudgeBanner extends StatelessWidget {
  const RiderNudgeBanner({super.key, required this.title, required this.message, required this.actions});

  final String title;
  final String message;

  /// [RiderNudgeButton]s, 8 apart.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.s16),
    decoration: BoxDecoration(
      color: RiderColors.white,
      borderRadius: BorderRadius.circular(AppSizes.s24),
      border: Border.all(color: RiderColors.hairline),
      boxShadow: RiderLayout.shadowShadow2x2_6,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSizes.s40,
              height: AppSizes.s40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: RiderColors.nudgeTile, borderRadius: BorderRadius.circular(RiderRadius.field)),
              child: Container(
                width: AppSizes.s18,
                height: AppSizes.s18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
                child: Container(
                  width: AppSizes.s6,
                  height: AppSizes.s6,
                  decoration: const BoxDecoration(color: RiderColors.white, shape: BoxShape.circle),
                ),
              ),
            ),
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
        const SizedBox(height: AppSizes.s12),
        Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSizes.s8),
              // Two are 141 and 145 wide in the design.
              Expanded(flex: actions.length == 2 ? (i == 0 ? AppLimits.flex141 : AppLimits.flex145) : AppLimits.flex1, child: actions[i]),
            ],
          ],
        ),
      ],
    ),
  );
}

/// The 48-high button of [RiderNudgeBanner]: filled green, or outlined.
class RiderNudgeButton extends StatelessWidget {
  const RiderNudgeButton(this.label, {super.key, required this.onPressed, this.outlined = false});

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSizes.s48,
    child: Material(
      color: outlined ? RiderColors.transparent : RiderColors.brand,
      shape: StadiumBorder(side: outlined ? const BorderSide(color: RiderColors.nudgeOutline, width: AppSizes.s1_5) : BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Center(
          child: RiderHugText(
            label,
            style: RiderText.labelLarge.copyWith(color: outlined ? RiderColors.ink : RiderColors.white),
          ),
        ),
      ),
    ),
  );
}

/// The pause bars on the break tile (Shift 43–45).
class RiderPauseGlyph extends StatelessWidget {
  const RiderPauseGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar() => Container(
      width: AppSizes.s9,
      height: AppSizes.s28,
      decoration: BoxDecoration(color: RiderColors.brand, borderRadius: BorderRadius.circular(AppSizes.s4_5)),
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [bar(), const SizedBox(width: AppSizes.s10), bar()]);
  }
}
