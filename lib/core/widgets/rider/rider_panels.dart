import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'rider_status.dart';
import 'rider_text.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_sizes.dart';
import '../../constants/app_numbers.dart';

/// White panel with a hairline border and the soft shadow, its children
/// [gap] apart (Home "Your ride", the pre-shift checklist, Shift 53).
class RiderPanel extends StatelessWidget {
  const RiderPanel({
    super.key,
    required this.children,
    this.gap = AppSizes.s12,
    this.radius = RiderRadius.card,
    this.padding = const EdgeInsets.all(AppSizes.s16),
  });

  final List<Widget> children;
  final double gap;

  /// 20 for the Home cards, 16 ([RiderRadius.field]) for Shift 53.
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: RiderColors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: radius == RiderRadius.field ? RiderColors.panelBorder : RiderColors.hairline),
      boxShadow: riderShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
      ],
    ),
  );
}

/// Label / value rows in a [RiderPanel], optionally under a title and split
/// by dividers: "Your ride · Stock · Spot · Scooter" (Shift 01–09), "Shift
/// starts · Ready in" (Shift 53).
class RiderSummaryCard extends StatelessWidget {
  const RiderSummaryCard({
    super.key,
    this.title,
    required this.rows,
    this.divided = true,
    this.radius = RiderRadius.card,
    this.valueColors = const {},
  });

  final String? title;

  /// (label, value) pairs.
  final List<(String, String)> rows;
  final bool divided;
  final double radius;

  /// By row, for values that aren't ink ("₹40", Handover 06).
  final Map<int, Color> valueColors;

  @override
  Widget build(BuildContext context) => RiderPanel(
    radius: radius,
    children: [
      if (title != null) Text(title!, style: RiderText.labelLarge),
      for (var i = 0; i < rows.length; i++) ...[
        if (divided && i > 0) const Divider(height: AppSizes.s1, thickness: AppSizes.s1, color: RiderColors.divider),
        _row(rows[i], valueColors[i], radius),
      ],
    ],
  );

  static Widget _row((String, String) row, Color? color, double radius) => SizedBox(
    height: AppSizes.s20,
    child: Row(
      children: [
        Expanded(
          child: Text(
            row.$1,
            maxLines: AppLimits.oneLine,
            overflow: TextOverflow.ellipsis,
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
          ),
        ),
        const SizedBox(width: AppSizes.s8),
        // A long gate name mustn't push the row off the card.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.s220),
          child: RiderHugText(
                  row.$2,
                  overflow: TextOverflow.ellipsis,
                  style: color == null ? RiderText.labelLarge : RiderText.labelLarge.copyWith(color: color),
                ),
        ),
      ],
    ),
  );
}

/// A checklist item: round check, title and grey hint (Shift 10–12).
class RiderCheckRow extends StatelessWidget {
  const RiderCheckRow({super.key, required this.title, this.subtitle, required this.checked, this.onTap});

  final String title;
  final String? subtitle;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: checked,
    button: onTap != null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          RiderCheckCircle(checked: checked),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: RiderText.labelLarge),
                if (subtitle != null) ...[const SizedBox(height: AppSizes.s2), Text(subtitle!, style: RiderText.caption)],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

enum RiderStepState { done, current, todo }

/// One step of a progress list: filled (done), green ring (current) or grey
/// ring (to do) with a title and optional hint ("Packing your order · Ready
/// in about 9 min", Shift 53).
class RiderStepRow extends StatelessWidget {
  const RiderStepRow({super.key, required this.title, this.subtitle, required this.state});

  final String title;
  final String? subtitle;
  final RiderStepState state;

  @override
  Widget build(BuildContext context) {
    final todo = state == RiderStepState.todo;
    return Row(
      children: [
        Container(
          width: AppSizes.s24,
          height: AppSizes.s24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == RiderStepState.done ? RiderColors.brand : null,
            border: state == RiderStepState.done
                ? null
                : Border.all(color: todo ? RiderColors.stepRing : RiderColors.brand, width: AppSizes.s2),
          ),
        ),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: RiderText.labelLarge.copyWith(color: todo ? RiderColors.grey : RiderColors.ink)),
              if (subtitle != null) ...[const SizedBox(height: AppSizes.s2), Text(subtitle!, style: RiderText.caption)],
            ],
          ),
        ),
      ],
    );
  }
}

/// Home header: "Good morning / Ravi" on the left; status chip and avatar on
/// the right (Shift 01–09, 51).
class RiderHomeHeader extends StatelessWidget {
  const RiderHomeHeader({
    super.key,
    required this.greeting,
    required this.name,
    this.status = const RiderStatusPill.offline(),
    this.onAvatarTap,
    this.avatarTint,
  });

  final String greeting;
  final String name;
  final Widget status;
  final VoidCallback? onAvatarTap;
  final Color? avatarTint;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: RiderText.caption),
            const SizedBox(height: AppSizes.s2),
            Text(name, style: RiderText.subheadingMedium, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      status,
      const SizedBox(width: AppSizes.s12),
      RiderAvatar(name, size: AppSizes.s40, onTap: onAvatarTap, tint: avatarTint),
    ],
  );
}

/// A push notification as Android shows it: app icon, "NINZO RIDER · now",
/// title, body and text actions (Notification 05–07).
class RiderNotificationCard extends StatelessWidget {
  const RiderNotificationCard({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.app = AppStrings.ninzoRider,
    this.when = AppStrings.now2,
  });

  final String title;
  final String body;

  /// Action labels; the first is the green one.
  final List<String> actions;
  final String app;
  final String when;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.s14),
    decoration: BoxDecoration(
      color: RiderColors.white,
      borderRadius: BorderRadius.circular(RiderRadius.card),
      // Figma's 4 blur; Flutter spreads the same number about 40% wider.
      boxShadow: RiderLayout.shadowShadow2x2_6,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppSizes.s40,
          height: AppSizes.s40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: RiderColors.brand, borderRadius: BorderRadius.circular(AppSizes.s10)),
          child: Text(AppStrings.textN, style: RiderText.labelLarge.copyWith(color: RiderColors.white)),
        ),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(app, style: RiderText.captionSmall)),
                  Text(when, style: RiderText.captionSmall),
                ],
              ),
              const SizedBox(height: AppSizes.s2),
              Text(title, style: RiderText.labelLarge),
              const SizedBox(height: AppSizes.s2),
              Text(body, style: RiderText.bodySmall.copyWith(color: RiderColors.grey)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSizes.s2),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSizes.s24),
                      Text(
                        actions[i],
                        style: RiderText.bodySmall.copyWith(color: i == 0 ? RiderColors.brand : RiderColors.black),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// A card whose title row opens a list: "▸ Items on scooter · 4 items" (Shift
/// 19), and each item with its quantity below (Shift 20).
class RiderItemsToggle extends StatelessWidget {
  const RiderItemsToggle({
    super.key,
    required this.title,
    required this.trailing,
    required this.open,
    required this.items,
    this.onTap,
  });

  final String title;
  final String trailing;
  final bool open;

  /// (name, quantity) pairs.
  final List<(String, String)> items;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: RiderColors.white,
      borderRadius: BorderRadius.circular(RiderRadius.card),
      border: Border.all(color: RiderColors.hairline),
      boxShadow: RiderLayout.shadowShadow2x2_6,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s14),
              child: Row(
                children: [
                  SizedBox.square(dimension: AppSizes.s12, child: CustomPaint(painter: _TogglePainter(open))),
                  const SizedBox(width: AppSizes.s12),
                  Expanded(child: Text(title, style: RiderText.labelLarge)),
                  const SizedBox(width: AppSizes.s12),
                  Text(trailing, style: RiderText.labelMedium.copyWith(color: RiderColors.grey)),
                ],
              ),
            ),
          ),
        ),
        if (open)
          for (final (name, quantity) in items) ...[
            const Divider(height: AppSizes.s1, thickness: AppSizes.s1, color: RiderColors.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s12),
              child: Row(
                children: [
                  Expanded(child: Text(name, style: RiderText.bodyMedium)),
                  const SizedBox(width: AppSizes.s12),
                  Text(quantity, style: RiderText.labelLarge),
                ],
              ),
            ),
          ],
      ],
    ),
  );
}

class _TogglePainter extends CustomPainter {
  const _TogglePainter(this.open);

  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / AppSizes.s12;
    final path = open
        ? (Path()
            ..moveTo(u, AppSizes.s2_5 * u)
            ..lineTo(AppSizes.s11 * u, AppSizes.s2_5 * u)
            ..lineTo(AppSizes.s6 * u, AppSizes.s10_5 * u))
        : (Path()
            ..moveTo(AppSizes.s2_5 * u, u)
            ..lineTo(AppSizes.s10_5 * u, AppSizes.s6 * u)
            ..lineTo(AppSizes.s2_5 * u, AppSizes.s11 * u));
    canvas.drawPath(path..close(), Paint()..color = RiderColors.grey);
  }

  @override
  bool shouldRepaint(_TogglePainter old) => old.open != open;
}

/// An assigned order: number, summary and a chip (Shift 28).
class RiderOrderCard extends StatelessWidget {
  const RiderOrderCard({super.key, required this.title, required this.subtitle, required this.chip, this.active = false});

  final String title;
  final String subtitle;

  /// "Now", "Next", "Queued".
  final String chip;

  /// Green chip.
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s12),
    decoration: BoxDecoration(
      color: RiderColors.white,
      borderRadius: BorderRadius.circular(RiderRadius.card),
      border: Border.all(color: RiderColors.hairline),
      boxShadow: RiderLayout.shadowShadow2x2_6,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: RiderText.labelLarge),
              const SizedBox(height: AppSizes.s2),
              Text(subtitle, style: RiderText.caption),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.s12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.s10, vertical: AppSizes.s4),
          decoration: BoxDecoration(
            color: active ? RiderColors.brandTint : RiderColors.hairline,
            borderRadius: BorderRadius.circular(RiderRadius.pill),
          ),
          child: Text(
            chip,
            style: RiderText.labelMedium.copyWith(color: active ? RiderColors.brand : RiderColors.grey),
          ),
        ),
      ],
    ),
  );
}

/// Amber banner over the main map: icon tile, title, grey line and a chip,
/// which is its action when [onChipTap] is set (Shift 29–32, 35, 40).
class RiderAlertBanner extends StatelessWidget {
  const RiderAlertBanner({super.key, required this.title, required this.message, this.chip, this.onChipTap});

  final String title;
  final String message;

  /// Null leaves the chip out.
  final String? chip;
  final VoidCallback? onChipTap;

  @override
  Widget build(BuildContext context) {
    final chipBody = Container(
      padding: const EdgeInsets.fromLTRB(AppSizes.s8, AppSizes.s4, AppSizes.s12, AppSizes.s4),
      decoration: BoxDecoration(color: RiderColors.warningChip, borderRadius: BorderRadius.circular(RiderRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSizes.s6,
            height: AppSizes.s6,
            decoration: const BoxDecoration(color: RiderColors.warningText, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSizes.s8),
          Text(chip ?? '', style: RiderText.labelSmall.copyWith(color: RiderColors.warningText)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSizes.s16),
      decoration: BoxDecoration(
        color: RiderColors.warningBanner,
        borderRadius: BorderRadius.circular(AppSizes.s24),
        border: Border.all(color: RiderColors.warningBannerBorder),
        boxShadow: RiderLayout.shadowShadow2x2_6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSizes.s40,
                height: AppSizes.s40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: RiderColors.warningBadge, borderRadius: BorderRadius.circular(AppSizes.s16)),
                child: Container(
                  width: AppSizes.s18,
                  height: AppSizes.s18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: RiderColors.warningText, shape: BoxShape.circle),
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
          if (chip != null) const SizedBox(height: AppSizes.s12),
          if (chip == null)
            const SizedBox.shrink()
          else if (onChipTap == null)
            chipBody
          else
            Semantics(
              button: true,
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onChipTap, child: chipBody),
            ),
        ],
      ),
    );
  }
}

/// Pills to choose one option from, wrapped and centred (Shift 33).
class RiderChoiceChips<T> extends StatelessWidget {
  const RiderChoiceChips({super.key, required this.options, required this.selected, required this.label, this.onSelected});

  final List<T> options;
  final T selected;
  final String Function(T) label;

  /// Null while they can't be changed.
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: AppSizes.s8,
    runSpacing: AppSizes.s8,
    children: [
      for (final option in options)
        Semantics(
          button: true,
          selected: option == selected,
          child: GestureDetector(
            onTap: onSelected == null ? null : () => onSelected!(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s10),
              decoration: BoxDecoration(
                color: option == selected ? RiderColors.haloOuter : RiderColors.white,
                borderRadius: BorderRadius.circular(RiderRadius.pill),
                border: Border.all(color: option == selected ? RiderColors.brand : RiderColors.track),
              ),
              child: Text(
                label(option),
                style: RiderText.labelMedium.copyWith(color: option == selected ? RiderColors.brand : RiderColors.ink),
              ),
            ),
          ),
        ),
    ],
  );
}
