import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'rider_text.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_sizes.dart';
import '../../constants/app_numbers.dart';

enum RiderButtonStyle {
  /// Green fill, white text (Button/Fill/Primary). Disabled: lighter green.
  primary,

  /// Green outline and text, transparent fill.
  secondary,

  /// Grey text only ("Not now", "Skip this order").
  ghost,

  /// Pale green fill, green text: the next turn (Order 02, 03).
  tinted,

  /// White fill, ink text: on green backgrounds (Welcome).
  inverse,

  /// White outline and text: on green backgrounds.
  inverseOutline,

  /// Red text and outline: destructive actions.
  danger,
}

/// Full-width pill button from the design: 56 high (ghost: 48).
class RiderButton extends StatelessWidget {
  const RiderButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.style = RiderButtonStyle.primary,
    this.loading = false,
    this.loadingLabel,
    this.icon,
    this.dimmed = false,
    this.leading,
  });

  const RiderButton.secondary(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.icon,
    this.dimmed = false,
    this.leading,
  }) : style = RiderButtonStyle.secondary;

  const RiderButton.ghost(
    this.label, {
    super.key,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.icon,
    this.dimmed = false,
    this.leading,
  }) : style = RiderButtonStyle.ghost;

  final String label;
  final VoidCallback? onPressed;
  final RiderButtonStyle style;

  /// Shows a spinner and ignores taps. The button keeps its colour.
  final bool loading;

  /// Text shown next to the spinner while [loading], e.g. "Verifying…".
  final String? loadingLabel;
  final IconData? icon;

  /// Drawn at 50% opacity in its normal colours, whether or not it can be
  /// tapped: "Starts at 9:00 AM" and "Waiting for the hub…" (disabled), the
  /// locked "Go online" link (still tappable, Shift 07).
  final bool dimmed;

  /// Custom icon next to the label, 10px apart (the turn arrow on Shift 52);
  /// wins over [icon].
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (Color fill, Color text, Color? border) = switch (style) {
      RiderButtonStyle.primary => (
        onPressed != null || dimmed ? RiderColors.brand : RiderColors.brandDisabled,
        RiderColors.white,
        null,
      ),
      RiderButtonStyle.secondary => (RiderColors.transparent, RiderColors.brand, RiderColors.brand),
      RiderButtonStyle.ghost => (RiderColors.transparent, RiderColors.grey, null),
      RiderButtonStyle.tinted => (RiderColors.brandTint, RiderColors.brand, null),
      RiderButtonStyle.inverse => (RiderColors.white, RiderColors.ink, null),
      RiderButtonStyle.inverseOutline => (RiderColors.transparent, RiderColors.white, RiderColors.white),
      RiderButtonStyle.danger => (RiderColors.transparent, RiderColors.error, RiderColors.error),
    };
    final faded = dimmed || (onPressed == null && style != RiderButtonStyle.primary);
    return Opacity(
      opacity: faded ? AppOpacity.o0_5 : AppOpacity.o1,
      child: SizedBox(
        width: double.infinity,
        height: style == RiderButtonStyle.ghost ? AppSizes.s48 : AppSizes.s56,
        child: Material(
          color: fill,
          shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border, width: AppSizes.s1_5)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading && loadingLabel == null
                  ? SizedBox.square(dimension: AppSizes.s22, child: CircularProgressIndicator(strokeWidth: AppSizes.s2_5, color: text))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (loading) ...[
                          // The stroke paints 20 across, in the design's 20 box 8 from the label.
                          const SizedBox(width: AppSizes.s1),
                          SizedBox.square(dimension: AppSizes.s18, child: CircularProgressIndicator(strokeWidth: AppSizes.s2, color: text)),
                          const SizedBox(width: AppSizes.s9),
                        ] else if (leading != null) ...[
                          leading!,
                          const SizedBox(width: AppSizes.s10),
                        ] else if (icon != null) ...[
                          Icon(icon, color: text, size: AppSizes.s20),
                          const SizedBox(width: AppSizes.s8),
                        ],
                        Flexible(
                          child: RiderHugText(
                            loading ? loadingLabel! : label,
                            style: RiderText.button.copyWith(color: text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 44px white circle with a soft shadow and a back arrow. [bordered] gives
/// the 48px variant with a hairline border used on the code screens.
class RiderBackButton extends StatelessWidget {
  const RiderBackButton({
    super.key,
    this.onPressed,
    this.icon = Icons.arrow_back,
    this.size = AppSizes.s44,
    this.bordered = false,
    this.label,
    this.softShadow = false,
  });

  /// The faint shadow of the code screen's bordered button (Login 04–11).
  final bool softShadow;

  /// What it says to screen readers, when it's not a way back.
  final String? label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double size;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label ?? (icon == Icons.close ? AppStrings.close : AppStrings.back),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: RiderColors.white,
          boxShadow: softShadow
              ? RiderLayout.inkFaintShadow2x2_6
              : (bordered ? null : riderShadow),
          border: bordered ? Border.all(color: RiderColors.track) : null,
        ),
        child: Material(
          color: RiderColors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed ?? () => Navigator.maybePop(context),
            // The border takes 1px on each side; the circle stays [size].
            child: SizedBox.square(
              dimension: bordered ? size - AppSizes.s2 : size,
              child: Icon(icon, size: AppSizes.s24, color: RiderColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small green text action, e.g. "View stock", "Manual", "Register".
class RiderLink extends StatelessWidget {
  const RiderLink(
    this.label, {
    super.key,
    required this.onPressed,
    this.style,
    this.padding = const EdgeInsets.symmetric(vertical: AppSizes.s4),
  });

  final String label;
  final VoidCallback? onPressed;
  final TextStyle? style;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(RiderRadius.s),
      child: Padding(
        padding: padding,
        child: RiderHugText(label, style: style ?? RiderText.labelLarge.copyWith(color: RiderColors.brand)),
      ),
    );
  }
}
