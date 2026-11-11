import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'rider_text.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_sizes.dart';
import '../../constants/app_keys.dart';
import '../../constants/app_numbers.dart';

/// Grey filled pill text field (Background/Overlay), 56 high.
class RiderTextField extends StatelessWidget {
  const RiderTextField({
    super.key,
    this.controller,
    this.hint,
    this.label,
    this.prefix,
    this.suffix,
    this.error,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final String? hint;

  /// Small label above the field.
  final String? label;
  final Widget? prefix;
  final Widget? suffix;

  /// Red message below; also turns the border red.
  final String? error;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(RiderRadius.card),
      borderSide: error == null ? BorderSide.none : const BorderSide(color: RiderColors.error, width: AppSizes.s1_5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[Text(label!, style: RiderText.labelLarge), const SizedBox(height: AppSizes.s8)],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          onChanged: onChanged,
          autofocus: autofocus,
          enabled: enabled,
          textCapitalization: textCapitalization,
          style: RiderText.bodyLarge,
          cursorColor: RiderColors.brand,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: RiderText.bodyLarge.copyWith(color: RiderColors.grey),
            filled: true,
            fillColor: RiderColors.overlay,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s16),
            prefixIcon: prefix,
            suffixIcon: suffix,
            border: border,
            enabledBorder: border,
            disabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: error == null ? RiderColors.brand : RiderColors.error, width: AppSizes.s1_5),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSizes.s8),
          Text(error!, style: RiderText.caption.copyWith(color: RiderColors.error)),
        ],
      ],
    );
  }
}

/// Row of digit boxes for OTP / delivery codes. Display only: pair it with
/// [RiderKeypad] (or a hidden field) for input.
///
/// Filled boxes are white with a soft shadow, the next box is outlined green
/// with a caret, empty boxes are a faint grey. [error] outlines every box and
/// digit in red; [dimmed] fades the row while the code is checked.
class RiderCodeBoxes extends StatelessWidget {
  const RiderCodeBoxes({
    super.key,
    required this.length,
    required this.value,
    this.error = false,
    this.dimmed = false,
    this.boxSize = AppSizes.s46,
    this.spread = false,
  }) : boxHeight = null,
       outlined = false;

  /// The 64 × 72 boxes of the customer code (Handover 02–05): white and
  /// outlined whether or not they're filled, with larger digits.
  const RiderCodeBoxes.large({
    super.key,
    required this.length,
    required this.value,
    this.error = false,
    this.dimmed = false,
  }) : boxSize = AppSizes.s64,
       boxHeight = AppSizes.s72,
       spread = false,
       outlined = true;

  final int length;
  final String value;
  final bool error;
  final bool dimmed;

  /// Box width; the height keeps the design's 46:56 ratio.
  final double boxSize;

  /// Spread the boxes across the full width (the login code row) instead of
  /// centring them 12px apart.
  final bool spread;

  /// Overrides the 46:56 ratio.
  final double? boxHeight;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final focusIndex = error || dimmed ? -1 : value.length;
    final digitStyle = outlined ? RiderText.metricLarge : RiderText.h4;
    Widget box(int i) {
      final filled = i < value.length;
      final focused = i == focusIndex;
      final Color fill;
      final Border? border;
      if (error) {
        fill = RiderColors.white;
        border = Border.all(color: RiderColors.error, width: AppSizes.s1_5);
      } else if (focused) {
        fill = RiderColors.white;
        border = Border.all(color: RiderColors.brand, width: AppSizes.s1_5);
      } else if (outlined) {
        fill = RiderColors.white;
        border = Border.all(color: RiderColors.divider);
      } else if (filled) {
        fill = RiderColors.white;
        border = null;
      } else {
        fill = RiderColors.codeSlot;
        border = Border.all(color: RiderColors.codeSlot);
      }
      return Container(
        width: boxSize,
        height: boxHeight ?? boxSize * AppSizes.s56 / AppSizes.s46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(RiderRadius.field),
          border: border,
          boxShadow: filled && !error && !outlined
              ? RiderLayout.shadowShadow2x3_46
              : null,
        ),
        child: filled
            ? Text(value[i], style: digitStyle.copyWith(color: error ? RiderColors.error : RiderColors.ink))
            : (focused
                  ? Container(
                      width: AppSizes.s2,
                      height: outlined ? AppSizes.s28 : AppSizes.s24,
                      decoration: BoxDecoration(
                        color: RiderColors.brand,
                        borderRadius: BorderRadius.circular(RiderRadius.pill),
                      ),
                    )
                  : null),
      );
    }

    return Opacity(
      opacity: dimmed ? AppOpacity.o0_6 : AppOpacity.o1,
      child: Row(
        mainAxisAlignment: spread ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
        children: [
          for (var i = 0; i < length; i++) ...[if (i > 0 && !spread) const SizedBox(width: AppSizes.s12), box(i)],
        ],
      ),
    );
  }
}

/// On-screen numeric keypad from the code-entry designs: white pill keys on a
/// light grey panel, 0 centred, delete (×) on the right.
class RiderKeypad extends StatelessWidget {
  const RiderKeypad({super.key, required this.onDigit, required this.onBackspace, this.enabled = true, this.keyWidth});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  /// Fixed keys from the left (Handover 02–05); by default they share the width.
  final double? keyWidth;

  @override
  Widget build(BuildContext context) {
    Widget sized(Widget child) => keyWidth == null ? Expanded(child: child) : SizedBox(width: keyWidth, child: child);
    Widget key({String? digit, VoidCallback? onTap, Widget? child, bool plain = false}) => sized(
      Material(
        color: plain ? RiderColors.transparent : RiderColors.white,
        borderRadius: BorderRadius.circular(RiderRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(RiderRadius.pill),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            height: AppSizes.s48,
            child: Center(child: child ?? Text(digit ?? '', style: RiderText.subheadingMedium)),
          ),
        ),
      ),
    );
    Widget digit(String d) => key(digit: d, onTap: () => onDigit(d));
    Widget row(List<Widget> keys) => Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[if (i > 0) const SizedBox(width: AppSizes.s4), keys[i]],
      ],
    );
    return Container(
      color: RiderColors.keypad,
      padding: const EdgeInsets.fromLTRB(AppSizes.s8, AppSizes.s8, AppSizes.s8, AppSizes.s12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row([digit(AppStrings.digit1), digit(AppStrings.digit2), digit(AppStrings.digit3)]),
            const SizedBox(height: AppSizes.s4),
            row([digit(AppStrings.digit4), digit(AppStrings.digit5), digit(AppStrings.digit6)]),
            const SizedBox(height: AppSizes.s4),
            row([digit(AppStrings.digit7), digit(AppStrings.digit8), digit(AppStrings.digit9)]),
            const SizedBox(height: AppSizes.s4),
            row([
              sized(const SizedBox()),
              digit(AppStrings.digit0),
              key(
                plain: true,
                onTap: onBackspace,
                child: Semantics(
                  label: AppStrings.delete,
                  button: true,
                  child: const Icon(Icons.close, color: RiderColors.ink, size: AppSizes.s24),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// How a [RiderPhoneField] is outlined.
enum RiderFieldTone { idle, active, error, warning }

/// Mobile number field from the login designs: country chip (flag, +91, ⌄)
/// and the number. Grey and borderless while empty and unfocused; white with a
/// green, red or amber outline otherwise.
class RiderPhoneField extends StatelessWidget {
  const RiderPhoneField({
    super.key,
    required this.controller,
    this.focusNode,
    this.tone = RiderFieldTone.idle,
    this.enabled = true,
    this.hint = AppStrings.mobileNumber,
    this.countryCode = AppStrings.indiaDialCode,
    this.flag = AppStrings.indiaFlag,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final RiderFieldTone tone;
  final bool enabled;
  final String hint;
  final String countryCode;
  final String flag;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final borderColor = switch (tone) {
      RiderFieldTone.idle => null,
      RiderFieldTone.active => RiderColors.brand,
      RiderFieldTone.error => RiderColors.error,
      RiderFieldTone.warning => RiderColors.warning,
    };
    return Opacity(
      opacity: enabled ? AppOpacity.o1 : AppOpacity.o0_6,
      child: Container(
        height: AppSizes.s56,
        padding: const EdgeInsets.only(left: AppSizes.s12, right: AppSizes.s16),
        decoration: BoxDecoration(
          color: borderColor == null ? RiderColors.inkFaint : RiderColors.white,
          borderRadius: BorderRadius.circular(RiderRadius.field),
          border: borderColor == null ? null : Border.all(color: borderColor, width: AppSizes.s1_5),
        ),
        child: Row(
          children: [
            Container(
              // Figma draws the chip's border inside its width.
              padding: const EdgeInsets.fromLTRB(AppSizes.s6, AppSizes.s8, AppSizes.s8, AppSizes.s8),
              decoration: BoxDecoration(
                color: RiderColors.white,
                borderRadius: BorderRadius.circular(RiderRadius.pill),
                border: Border.all(color: RiderColors.track),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Android's flag glyph runs wider than the design's: it keeps an 18px slot.
                  SizedBox(
                    width: AppSizes.s18,
                    child: Text(flag, maxLines: AppLimits.oneLine, style: RiderText.phoneFlag),
                  ),
                  const SizedBox(width: AppSizes.s4),
                  RiderHugText(countryCode, style: RiderText.labelLarge),
                  const SizedBox(width: AppSizes.s4),
                  const Icon(Icons.keyboard_arrow_down, size: AppSizes.s16, color: RiderColors.grey),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.s12),
            Expanded(
              child: TextField(
                key: const Key(AppKeys.phonefield),
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: inputFormatters,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                style: RiderText.bodyLargeTight,
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
                  hintStyle: RiderText.bodyLargeTight.copyWith(color: RiderColors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 20px rounded checkbox with a label, e.g. "Keep me signed in on this phone".
/// An option with a 22px radio on the right (Order 04).
class RiderRadioRow extends StatelessWidget {
  const RiderRadioRow({super.key, required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(label, style: RiderText.labelLarge)),
          Container(
            width: AppSizes.s22,
            height: AppSizes.s22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? RiderColors.brand : RiderColors.divider, width: AppSizes.s1_5),
            ),
            child: selected
                ? Container(
                    width: AppSizes.s10,
                    height: AppSizes.s10,
                    decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
                  )
                : null,
          ),
        ],
      ),
    ),
  );
}

/// A choice on its own card: round radio, title and hint (Problem 01, 02).
class RiderOptionCard extends StatelessWidget {
  const RiderOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s16),
        decoration: BoxDecoration(
          color: selected ? RiderColors.optionSelected : RiderColors.white,
          borderRadius: BorderRadius.circular(RiderRadius.field),
          border: selected ? Border.all(color: RiderColors.brand, width: AppSizes.s2) : Border.all(color: RiderColors.panelBorder),
        ),
        child: Row(
          children: [
            Container(
              width: AppSizes.s24,
              height: AppSizes.s24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? RiderColors.brand : RiderColors.stepRing, width: AppSizes.s2),
              ),
              child: selected
                  ? Container(
                      width: AppSizes.s12,
                      height: AppSizes.s12,
                      decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
                    )
                  : null,
            ),
            const SizedBox(width: AppSizes.s12),
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
          ],
        ),
      ),
    ),
  );
}

/// − number + with 40px pale green buttons (Handover 08, 09).
class RiderRoundStepper extends StatelessWidget {
  const RiderRoundStepper({super.key, required this.value, required this.onMinus, required this.onPlus});

  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget button(String glyph, String label, VoidCallback onTap) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: AppSizes.s40,
          height: AppSizes.s40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: RiderColors.brandTint, shape: BoxShape.circle),
          child: Text(glyph, style: RiderText.h4.copyWith(color: RiderColors.brand)),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(AppStrings.minusSign, AppStrings.less, onMinus),
        const SizedBox(width: AppSizes.s12),
        Text('$value', style: RiderText.h4),
        const SizedBox(width: AppSizes.s12),
        button(AppStrings.plusSign, AppStrings.more, onPlus),
      ],
    );
  }
}

class RiderCheckboxRow extends StatelessWidget {
  const RiderCheckboxRow({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(RiderRadius.s),
        child: Row(
          children: [
            Container(
              width: AppSizes.s20,
              height: AppSizes.s20,
              decoration: BoxDecoration(
                color: value ? RiderColors.brand : RiderColors.white,
                borderRadius: BorderRadius.circular(RiderRadius.s),
                border: value ? null : Border.all(color: RiderColors.divider, width: AppSizes.s1_5),
              ),
              child: value ? const Icon(Icons.check, size: AppSizes.s16, color: RiderColors.white) : null,
            ),
            const SizedBox(width: AppSizes.s12),
            Expanded(child: Text(label, style: RiderText.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// Info icon and a message under a field: red for errors, amber for holds.
class RiderInlineMessage extends StatelessWidget {
  const RiderInlineMessage(
    this.message, {
    super.key,
    this.color = RiderColors.error,
    this.iconColor,
    this.centerIcon = false,
  });

  /// Amber "on hold" style.
  const RiderInlineMessage.warning(this.message, {super.key})
    : color = RiderColors.warningText,
      iconColor = RiderColors.warning,
      centerIcon = false;

  /// Icon centred on the text lines (Login 06, 11); top aligned by default.
  final bool centerIcon;
  final String message;
  final Color color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: centerIcon ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // The glyph fills 5/6 of its box; 26.4 draws the design's 22px ring.
        SizedBox.square(
          dimension: AppSizes.s24,
          child: OverflowBox(
            maxWidth: AppSizes.s26_4,
            maxHeight: AppSizes.s26_4,
            child: Icon(Icons.error_outline, size: AppSizes.s26_4, color: iconColor ?? color),
          ),
        ),
        const SizedBox(width: AppSizes.s8),
        Expanded(
          child: Text(message, style: RiderText.bodyMedium.copyWith(color: color)),
        ),
      ],
    );
  }
}
