import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'rider_text.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_sizes.dart';
import '../../constants/app_keys.dart';
import '../../constants/app_numbers.dart';

/// Rounded pill with a dot and label, e.g. "● Online", "● New order assigned".
class RiderStatusPill extends StatelessWidget {
  /// "Added", on a document that's in.
  static const added = RiderStatusPill.chip(AppStrings.added);

  const RiderStatusPill(
    this.label, {
    super.key,
    this.color = RiderColors.brand,
    this.dot = true,
    this.tint,
    this.textColor,
    this.compact = false,
  });

  /// The 24px chip of the register designs ("● Added", "● Under review"):
  /// 6px dot, 4px vertical padding.
  const RiderStatusPill.chip(this.label, {super.key, this.color = RiderColors.brand, this.textColor, this.tint})
    : dot = true,
      compact = true;

  /// Grey "● Offline" pill.
  const RiderStatusPill.offline({super.key, this.label = AppStrings.offline})
    : color = RiderColors.grey,
      dot = true,
      tint = null,
      textColor = null,
      compact = false;

  final String label;
  final Color color;
  final bool dot;
  final Color? tint;

  /// Label colour; defaults to [color].
  final Color? textColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dotSize = compact ? AppSizes.s6_0 : AppSizes.s8_0;
    return Container(
      padding: compact
          ? EdgeInsets.fromLTRB(dot ? AppSizes.s8 : AppSizes.s12, AppSizes.s4, AppSizes.s12, AppSizes.s4)
          : const EdgeInsets.symmetric(horizontal: AppSizes.s12, vertical: AppSizes.s8),
      decoration: BoxDecoration(
        color: tint ?? color.withValues(alpha: compact ? AppOpacity.o0_123 : (color == RiderColors.grey ? AppOpacity.greyPill : color == RiderColors.brand ? AppOpacity.o0_12 : AppOpacity.o0_14)),
        borderRadius: BorderRadius.circular(RiderRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSizes.s8),
          ],
          RiderHugText(label, style: RiderText.labelSmall.copyWith(color: textColor ?? color)),
        ],
      ),
    );
  }
}

/// Circle with the rider's initial on a tinted background.
class RiderAvatar extends StatelessWidget {
  const RiderAvatar(this.name, {super.key, this.size = AppSizes.s44, this.onTap, this.tint});

  final Color? tint;

  final String name;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '' : name.trim().characters.first.toUpperCase();
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tint ?? RiderColors.avatarTint, shape: BoxShape.circle),
      child: Text(
        initial,
        style: (size >= AppSizes.s64
                ? RiderText.h4
                : size <= AppSizes.s40
                ? RiderText.labelLarge
                : RiderText.subheadingSmall)
            .copyWith(color: RiderColors.brand),
      ),
    );
    return onTap == null
        ? avatar
        : Semantics(
            button: true,
            label: AppStrings.profile,
            child: GestureDetector(onTap: onTap, child: avatar),
          );
  }
}

/// Segmented progress bars at the top of multi-step flows.
class RiderStepBars extends StatelessWidget {
  const RiderStepBars({
    super.key,
    required this.total,
    required this.done,
    this.inactive = RiderColors.overlay,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSizes.s16),
  });

  final int total;
  final EdgeInsets padding;

  /// Steps filled green.
  final int done;
  final Color inactive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: AppSizes.s8),
            Expanded(
              child: Container(
                height: AppSizes.s4,
                decoration: BoxDecoration(
                  color: i < done ? RiderColors.brand : inactive,
                  borderRadius: BorderRadius.circular(RiderRadius.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thin green progress bar on a light track.
class RiderProgressBar extends StatelessWidget {
  const RiderProgressBar(this.value, {super.key, this.color = RiderColors.brand, this.track = RiderColors.overlay});

  /// 0–1.
  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RiderRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: AppSizes.s6,
        color: color,
        backgroundColor: track,
      ),
    );
  }
}

/// The 96px countdown ring: "1:30 / to deliver".
class RiderCountdownRing extends StatelessWidget {
  const RiderCountdownRing({
    super.key,
    required this.label,
    required this.caption,
    required this.progress,
    this.color = RiderColors.brand,
    this.size = AppSizes.s96,
  });

  /// e.g. "1:30".
  final String label;

  /// e.g. "to deliver".
  final String caption;

  /// 1 = full ring, 0 = empty.
  final double progress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(progress.clamp(0, 1), color),
        // "Almost" (Order 03) is wider than the ring: it runs over both sides,
        // as designed.
        child: OverflowBox(
          minWidth: AppSizes.s0,
          minHeight: AppSizes.s0,
          maxWidth: size * 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                key: const Key(AppKeys.countdown),
                style: RiderText.metricLarge.copyWith(color: RiderColors.ink),
              ),
              Text(caption, style: RiderText.labelSmall.copyWith(color: RiderColors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = AppSizes.s4_8;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = RiderColors.grey.withValues(alpha: AppOpacity.o0_14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

/// Round check used in checklists and permission benefit rows.
class RiderCheckCircle extends StatelessWidget {
  const RiderCheckCircle({super.key, required this.checked, this.size = AppSizes.s24});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? RiderColors.brand : RiderColors.transparent,
        border: checked ? null : Border.all(color: RiderColors.divider, width: AppSizes.s1_5),
      ),
      child: checked ? Icon(Icons.check, size: size * AppSizes.s0_7, color: RiderColors.white) : null,
    );
  }
}

/// Coloured notice box for alerts ("Low stock", "Weak signal").
class RiderNotice extends StatelessWidget {
  const RiderNotice({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.color = RiderColors.warning,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.o0_1),
        borderRadius: BorderRadius.circular(RiderRadius.m),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppSizes.s20),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: RiderText.labelLargeTight),
                if (message != null) Text(message!, style: RiderText.caption),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: AppSizes.s8), action!],
        ],
      ),
    );
  }
}
