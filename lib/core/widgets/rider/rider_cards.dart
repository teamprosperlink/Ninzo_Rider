import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../constants/app_sizes.dart';
import '../../constants/app_numbers.dart';
import '../../constants/app_strings.dart';

/// White card with 20 radius and the soft shadow. Children are separated by
/// dividers when [divided] is true.
class RiderCard extends StatelessWidget {
  const RiderCard({
    super.key,
    required this.children,
    this.divided = true,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s4),
    this.color = RiderColors.white,
    this.borderColor,
  });

  final List<Widget> children;
  final bool divided;
  final EdgeInsets padding;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(RiderRadius.card),
        boxShadow: riderShadow,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (divided && i > 0) const Divider(height: AppSizes.s1, thickness: AppSizes.s1, color: RiderColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// 40px rounded square with a tinted fill and an icon (list row leading).
class RiderIconTile extends StatelessWidget {
  const RiderIconTile(this.icon, {super.key, this.color = RiderColors.brand, this.tint, this.size = AppSizes.s40});

  final IconData icon;
  final Color color;
  final Color? tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint ?? color.withValues(alpha: AppOpacity.o0_1),
        borderRadius: BorderRadius.circular(RiderRadius.m),
      ),
      child: Icon(icon, color: color, size: size * AppSizes.s0_5),
    );
  }
}

/// List row: leading, title + subtitle, trailing. Used inside [RiderCard].
class RiderListRow extends StatelessWidget {
  const RiderListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.padding = const EdgeInsets.symmetric(vertical: AppSizes.s12),
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSizes.s12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RiderText.labelLargeTight.copyWith(color: titleColor ?? RiderColors.ink),
                ),
                if (subtitle != null) ...[const SizedBox(height: AppSizes.s2), Text(subtitle!, style: RiderText.caption)],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AppSizes.s12), trailing!],
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Label on the left (grey), value on the right (ink, medium).
class RiderKeyValueRow extends StatelessWidget {
  const RiderKeyValueRow(this.label, this.value, {super.key, this.valueColor, this.valueStyle});

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
          ),
          Text(value, style: valueStyle ?? RiderText.labelLarge.copyWith(color: valueColor ?? RiderColors.ink)),
        ],
      ),
    );
  }
}

/// Item name and "× 2" quantity, as in the order and stock lists.
class RiderItemRow extends StatelessWidget {
  const RiderItemRow(this.name, this.quantity, {super.key, this.trailing});

  final String name;
  final int quantity;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.s12),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
          ),
          trailing ?? Text(AppStrings.timesCount(quantity), style: RiderText.labelLarge),
        ],
      ),
    );
  }
}

/// Row of small stats: "0 Orders · ₹0 Earned · 0:12 Online".
class RiderStatsCard extends StatelessWidget {
  const RiderStatsCard(this.stats, {super.key});

  /// (value, label) pairs.
  final List<(String, String)> stats;

  static Widget _column(double? width, Widget child) =>
      width == null ? Expanded(child: child) : SizedBox(width: width, child: child);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.s16),
      decoration: BoxDecoration(
        color: RiderColors.white,
        borderRadius: BorderRadius.circular(RiderRadius.card),
        border: Border.all(color: RiderColors.hairline),
        boxShadow: riderShadow,
      ),
      child: Row(
        children: [
          for (final (i, (value, label)) in stats.indexed)
            _column(
              // Three columns are 98.667 wide in the design, 2px over the inner width.
              stats.length == AppLimits.threeStats && i < 2 ? AppSizes.s98_667 : null,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: RiderText.subheadingMedium),
                  const SizedBox(height: AppSizes.s2),
                  Text(label, style: RiderText.caption),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
