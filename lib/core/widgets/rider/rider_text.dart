import 'package:flutter/widgets.dart';
import '../../constants/app_sizes.dart';
import '../../constants/app_numbers.dart';

/// One line of text in a box of whole pixels, as Figma sizes hugging text.
/// The text sits at the box's left, so right-aligned and centred labels and
/// the pills around them land where the design has them.
class RiderHugText extends StatelessWidget {
  const RiderHugText(this.text, {super.key, required this.style, this.overflow});

  final String text;
  final TextStyle style;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: AppLimits.oneLine,
    )..layout();
    final natural = painter.width;
    final height = painter.height;
    painter.dispose();
    return CustomSingleChildLayout(
      delegate: _HugLayout(natural: natural, height: height, spacing: style.letterSpacing ?? AppSizes.s0),
      child: Text(text, style: style, maxLines: AppLimits.oneLine, overflow: overflow, textAlign: TextAlign.left),
    );
  }
}

/// Figma's box leaves out the spacing after the last letter, and Figma puts no
/// spacing before the first one, where Flutter puts half.
class _HugLayout extends SingleChildLayoutDelegate {
  _HugLayout({required this.natural, required this.height, required this.spacing});

  final double natural;
  final double height;
  final double spacing;

  double get _width => (natural - spacing).ceilToDouble();

  @override
  Size getSize(BoxConstraints constraints) => constraints.constrain(Size(_width, height));

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.maxWidth < _width
      ? BoxConstraints(maxWidth: constraints.maxWidth)
      : BoxConstraints.tightFor(width: natural);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      childSize.width < natural ? Offset.zero : Offset(-spacing / 2, AppSizes.s0);

  @override
  bool shouldRelayout(_HugLayout old) => old.natural != natural || old.height != height || old.spacing != spacing;
}

/// Spaced capitals at the left of their box. Flutter puts half the letter
/// spacing before the first letter; Figma doesn't.
class RiderLeftOverline extends StatelessWidget {
  const RiderLeftOverline(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(-style.letterSpacing! / 2, AppSizes.s0),
    child: Text(text, style: style),
  );
}
