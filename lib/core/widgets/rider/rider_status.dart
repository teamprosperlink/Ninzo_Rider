import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/rider_tokens.dart';
import 'rider_text.dart';

/// Rounded pill with a dot and label, e.g. "● Online", "● New order assigned".
class RiderStatusPill extends StatelessWidget {
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
  const RiderStatusPill.chip(this.label, {super.key, this.color = RiderColors.brand, this.textColor})
    : dot = true,
      tint = null,
      compact = true;

  /// Grey "● Offline" pill.
  const RiderStatusPill.offline({super.key, this.label = 'Offline'})
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
    final dotSize = compact ? 6.0 : 8.0;
    return Container(
      padding: compact
          ? EdgeInsets.fromLTRB(dot ? 8 : 12, 4, 12, 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint ?? color.withValues(alpha: compact ? 0.123 : (color == RiderColors.grey ? 0x23 / 255 : 0.14)),
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
            const SizedBox(width: 8),
          ],
          compact
              ? Text(label, style: RiderText.labelSmall.copyWith(color: textColor ?? color))
              : RiderHugText(label, style: RiderText.labelSmall.copyWith(color: textColor ?? color)),
        ],
      ),
    );
  }
}

/// Circle with the rider's initial on a tinted background.
class RiderAvatar extends StatelessWidget {
  const RiderAvatar(this.name, {super.key, this.size = 44, this.onTap});

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
      decoration: const BoxDecoration(color: RiderColors.avatarTint, shape: BoxShape.circle),
      child: Text(
        initial,
        style: (size >= 64
                ? RiderText.h4
                : size <= 40
                ? RiderText.labelLarge
                : RiderText.subheadingSmall)
            .copyWith(color: RiderColors.brand),
      ),
    );
    return onTap == null
        ? avatar
        : Semantics(
            button: true,
            label: 'Profile',
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
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
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
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 4,
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
        minHeight: 6,
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
    this.size = 96,
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
          minWidth: 0,
          minHeight: 0,
          maxWidth: size * 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                key: const Key('countdown'),
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
    const stroke = 4.8;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = RiderColors.grey.withValues(alpha: 0.14)
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
  const RiderCheckCircle({super.key, required this.checked, this.size = 24});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? RiderColors.brand : Colors.transparent,
        border: checked ? null : Border.all(color: RiderColors.divider, width: 1.5),
      ),
      child: checked ? Icon(Icons.check, size: size * 0.7, color: RiderColors.white) : null,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(RiderRadius.m),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: RiderText.labelLarge.copyWith(height: 20 / 14)),
                if (message != null) Text(message!, style: RiderText.caption),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}
