import 'package:flutter/material.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../core/constants/app_sizes.dart';

/// Figma's 6 blur on the selected segment; see the note in `app_theme.dart`.

/// A profile screen's frame: bordered 48 back, title, 16 to the content.
class ProfileScaffold extends StatelessWidget {
  const ProfileScaffold({super.key, required this.title, required this.onBack, required this.children, this.bottom});

  final String title;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => RiderScaffold(
    title: title,
    onBack: onBack,
    backSize: AppSizes.s48,
    backBordered: true,
    headerPadding: RiderHeader.flowPadding,
    bodyPadding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
    bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s12),
    bottom: [?bottom],
    // Figma clips the body to its content, cutting the last card's shadow and
    // every card's side shadow.
    children: [
      ClipRect(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ],
  );
}

/// White card, 20 radius, with full-width dividers between its rows.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: RiderColors.white,
      borderRadius: BorderRadius.circular(RiderRadius.card),
      border: Border.all(color: RiderColors.hairline),
      boxShadow: riderShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const ColoredBox(color: RiderColors.divider, child: SizedBox(height: AppSizes.s1)),
          rows[i],
        ],
      ],
    ),
  );
}

/// Avatar, name and role (Profile 01, 07).
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSizes.s8),
    child: Column(
      children: [
        Container(
          width: AppSizes.s88,
          height: AppSizes.s88,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: RiderColors.haloOuter, shape: BoxShape.circle),
          child: Text(
            name.trim().isEmpty ? '' : name.trim().characters.first.toUpperCase(),
            style: RiderText.h4.copyWith(color: RiderColors.brand),
          ),
        ),
        const SizedBox(height: AppSizes.s8),
        Text(name, style: RiderText.subheadingSmall),
        const SizedBox(height: AppSizes.s8),
        Text(role, style: RiderText.caption),
      ],
    ),
  );
}

/// Grey label, value on the right (Profile 04, 07).
class ProfileValueRow extends StatelessWidget {
  const ProfileValueRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSizes.s16),
    child: Row(
      children: [
        Expanded(child: Text(label, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey))),
        RiderHugText(value, style: RiderText.labelLarge),
      ],
    ),
  );
}

/// Two lines, with an optional value on the right (Profile 06, 09).
class ProfileTwoLineRow extends StatelessWidget {
  const ProfileTwoLineRow({super.key, required this.title, required this.subtitle, this.trailing, this.onTap});

  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s14),
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
          if (trailing != null) RiderHugText(trailing!, style: RiderText.labelLarge),
        ],
      ),
    ),
  );
}

/// The grey track with its segments: 150 wide at the frames' 360, with the
/// 16 they leave on the right (Profile 02, 06, 09).
class ProfileSegments extends StatelessWidget {
  const ProfileSegments({super.key, required this.labels, required this.selected, this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.s4),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: RiderColors.segmentTrack, borderRadius: BorderRadius.circular(RiderRadius.pill)),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSizes.s4),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelected == null ? null : () => onSelected!(i),
              child: Container(
                height: AppSizes.s40,
                alignment: Alignment.center,
                decoration: i == selected
                    ? BoxDecoration(
                        color: RiderColors.white,
                        borderRadius: BorderRadius.circular(RiderRadius.pill),
                        boxShadow: RiderLayout.profileSegmentShadow,
                      )
                    : null,
                child: RiderHugText(
                  labels[i],
                  style: RiderText.labelLarge.copyWith(color: i == selected ? RiderColors.ink : RiderColors.grey),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: AppSizes.s16),
      ],
    ),
  );
}
