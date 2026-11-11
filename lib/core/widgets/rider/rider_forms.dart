import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'rider_inputs.dart';
import 'rider_status.dart';
import 'rider_text.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_sizes.dart';
import '../../constants/app_numbers.dart';

/// 32px rounded tile (brand 10%) with a 16px icon: leading of form fields
/// and place rows in the register designs.
class RiderSmallIconTile extends StatelessWidget {
  const RiderSmallIconTile(
    this.icon, {
    super.key,
    this.color = RiderColors.brand,
    this.size = AppSizes.s32,
    this.radius = AppSizes.s12,
    this.alpha = AppOpacity.o0_1,
  });

  /// Of [color] on the tile.
  final double alpha;
  final IconData icon;
  final Color color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Icon(icon, size: size / 2, color: color),
  );
}

/// 56px field with a leading icon tile (Register 01 "Full name", "Your
/// area"; Register 14 search). Grey and borderless while idle; white with a
/// green ([RiderFieldTone.active]) or red outline otherwise.
///
/// Editable with a [controller]; otherwise shows [value] (or [hint]) and
/// calls [onTap], like the area field that opens the search.
class RiderIconField extends StatelessWidget {
  const RiderIconField({
    super.key,
    required this.icon,
    this.controller,
    this.focusNode,
    this.value,
    this.hint,
    this.tone = RiderFieldTone.idle,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.inputFormatters,
    this.autofocus = false,
    this.enabled = true,
    this.fieldKey,
  });

  final IconData icon;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Shown when there is no [controller].
  final String? value;
  final String? hint;
  final RiderFieldTone tone;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool enabled;

  /// Key of the inner text field (for tests).
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (tone) {
      RiderFieldTone.idle => null,
      RiderFieldTone.active => RiderColors.brand,
      RiderFieldTone.error => RiderColors.error,
      RiderFieldTone.warning => RiderColors.warning,
    };
    final textStyle = RiderText.bodyLargeTight;
    final hintStyle = textStyle.copyWith(color: RiderColors.grey);
    final Widget text = controller != null
        ? TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            textCapitalization: textCapitalization,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: textStyle,
            cursorColor: RiderColors.brand,
            cursorWidth: AppSizes.s2,
            cursorHeight: AppSizes.s22,
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintText: hint,
              hintStyle: hintStyle,
            ),
          )
        : Text(
            value ?? hint ?? '',
            key: fieldKey,
            style: value == null ? hintStyle : textStyle,
            maxLines: AppLimits.oneLine,
            overflow: TextOverflow.ellipsis,
          );
    final field = Container(
      height: AppSizes.s56,
      padding: const EdgeInsets.only(left: AppSizes.s12, right: AppSizes.s16),
      decoration: BoxDecoration(
        color: borderColor == null ? RiderColors.inkFaint : RiderColors.white,
        borderRadius: BorderRadius.circular(RiderRadius.field),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor, width: AppSizes.s1_5),
      ),
      child: Row(
        children: [
          RiderSmallIconTile(icon),
          const SizedBox(width: AppSizes.s12),
          Expanded(child: text),
        ],
      ),
    );
    if (controller != null || onTap == null) return field;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: field,
      ),
    );
  }
}

/// Label above a form field (Label/Large, 8px gap).
class RiderLabeledField extends StatelessWidget {
  const RiderLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.message,
  });

  final String label;
  final Widget child;

  /// Shown 8px under the field, e.g. a [RiderInlineMessage].
  final Widget? message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: RiderText.labelLarge),
      const SizedBox(height: AppSizes.s8),
      child,
      if (message != null) ...[const SizedBox(height: AppSizes.s8), message!],
    ],
  );
}

/// Segmented bars with "Step 1 of 3 · Details" under them.
class RiderStepProgress extends StatelessWidget {
  const RiderStepProgress({
    super.key,
    required this.step,
    required this.total,
    required this.label,
  });

  final int step;
  final int total;

  /// "Details", shown as "Step 1 of 3 · Details".
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      RiderStepBars(
        total: total,
        done: step,
        inactive: RiderColors.track,
        padding: EdgeInsets.zero,
      ),
      const SizedBox(height: AppSizes.s8),
      Text(AppStrings.stepOf(step, total, label), style: RiderText.caption),
    ],
  );
}

/// One 64px row of a place list (Register 14–16): location tile, name (or
/// action) and a caption, with a divider underneath.
class RiderPlaceRow extends StatelessWidget {
  const RiderPlaceRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.person_pin_circle_outlined,
    this.highlight = false,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Green title, for "Use my current location".
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      height: AppSizes.s64,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: RiderColors.divider)),
      ),
      child: Row(
        children: [
          RiderSmallIconTile(icon, alpha: AppOpacity.o0_105),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RiderText.bodyLarge.copyWith(
                    height: AppSizes.s20 / AppSizes.s16,
                    color: highlight ? RiderColors.brand : RiderColors.ink,
                  ),
                  maxLines: AppLimits.oneLine,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.s2),
                Text(
                  subtitle,
                  style: RiderText.caption,
                  maxLines: AppLimits.oneLine,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// White card with a hairline border and soft shadow whose rows are split
/// by hairlines (Register 04, 08–13).
class RiderInfoCard extends StatelessWidget {
  const RiderInfoCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s4),
    decoration: BoxDecoration(
      color: RiderColors.white,
      borderRadius: BorderRadius.circular(RiderRadius.card),
      border: Border.all(color: RiderColors.hairline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(height: AppSizes.s1, thickness: AppSizes.s1, color: RiderColors.hairline),
          children[i],
        ],
      ],
    ),
  );
}

/// Label and value (or a chip) in a [RiderInfoCard]: 12px vertical padding.
class RiderInfoRow extends StatelessWidget {
  const RiderInfoRow(
    this.label, {
    super.key,
    this.value,
    this.trailing,
    this.labelColor = RiderColors.grey,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final Color labelColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSizes.s12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: RiderText.bodyMedium.copyWith(color: labelColor),
          ),
        ),
        if (value != null) RiderHugText(value!, style: RiderText.labelLarge),
        ?trailing,
      ],
    ),
  );
}

/// Amber tip box with a small icon tile ("Blurry or cut-off photos get
/// rejected…").
class RiderTip extends StatelessWidget {
  const RiderTip(this.message, {super.key, this.icon = Icons.schedule_rounded});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(AppSizes.s12, AppSizes.s12, AppSizes.s16, AppSizes.s12),
    decoration: BoxDecoration(
      color: RiderColors.tipFill,
      borderRadius: BorderRadius.circular(RiderRadius.field),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppSizes.s28,
          height: AppSizes.s28,
          decoration: BoxDecoration(
            color: RiderColors.tipTile,
            borderRadius: BorderRadius.circular(RiderRadius.s),
          ),
          child: Icon(icon, size: AppSizes.s16, color: RiderColors.brand),
        ),
        const SizedBox(width: AppSizes.s12),
        Expanded(
          child: Text(
            message,
            style: RiderText.caption.copyWith(color: RiderColors.ink),
          ),
        ),
      ],
    ),
  );
}

/// Dark 300px camera frame with four white corner marks and a caption
/// (Register 05, Stock 01). [preview] is a live camera picture behind the
/// marks.
class RiderViewfinder extends StatelessWidget {
  const RiderViewfinder({
    super.key,
    this.caption,
    this.radius = AppSizes.s24,
    this.cornerStroke = AppSizes.s3,
    this.preview,
    this.onTap,
  });

  final String? caption;
  final double radius;
  final double cornerStroke;
  final Widget? preview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.s300,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: RiderColors.viewfinder,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Stack(
      children: [
        if (preview != null) Positioned.fill(child: preview!),
        if (onTap != null)
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
          ),
        Align(
          alignment: Alignment.center,
          child: IgnorePointer(
            child: SizedBox(
              width: AppSizes.s130,
              height: AppSizes.s130,
              child: CustomPaint(painter: _CornersPainter(cornerStroke)),
            ),
          ),
        ),
        if (caption != null)
          Positioned(
            left: AppSizes.s0,
            right: AppSizes.s0,
            top: AppSizes.s256,
            child: IgnorePointer(
              child: Text(
                caption!,
                textAlign: TextAlign.center,
                style: RiderText.labelMedium.copyWith(color: RiderColors.white),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The gate's viewfinder (Arrival 01, 04): 360px, a rounded white frame and the
/// caption under it.
class RiderGateViewfinder extends StatelessWidget {
  const RiderGateViewfinder({super.key, required this.caption, this.preview, this.onTap});

  final String caption;

  /// The live camera, behind the frame.
  final Widget? preview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.s360,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: RiderColors.ink, borderRadius: BorderRadius.circular(AppSizes.s24)),
    child: Stack(
      children: [
        if (preview != null) Positioned.fill(child: preview!),
        if (onTap != null)
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
          ),
        Positioned(
          left: AppSizes.s64,
          top: AppSizes.s60,
          child: IgnorePointer(
            child: Container(
              width: AppSizes.s200,
              height: AppSizes.s200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.s24),
                border: Border.all(color: RiderColors.white, width: AppSizes.s3),
              ),
            ),
          ),
        ),
        Positioned(
          left: AppSizes.s64,
          top: AppSizes.s290,
          child: IgnorePointer(
            child: Text(caption, style: RiderText.labelLarge.copyWith(color: RiderColors.white)),
          ),
        ),
      ],
    ),
  );
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter(this.stroke);

  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = AppSizes.s28_0;
    final paint = Paint()
      ..color = RiderColors.white
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(AppSizes.s0, arm)
      ..lineTo(AppSizes.s0, AppSizes.s0)
      ..lineTo(arm, AppSizes.s0)
      ..moveTo(w - arm, AppSizes.s0)
      ..lineTo(w, AppSizes.s0)
      ..lineTo(w, arm)
      ..moveTo(AppSizes.s0, h - arm)
      ..lineTo(AppSizes.s0, h)
      ..lineTo(arm, h)
      ..moveTo(w - arm, h)
      ..lineTo(w, h)
      ..lineTo(w, h - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => oldDelegate.stroke != stroke;
}
