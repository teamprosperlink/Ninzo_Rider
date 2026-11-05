import 'package:flutter/widgets.dart';

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
      maxLines: 1,
    )..layout();
    // Allows for Flutter measuring a hair wider than Figma.
    final width = (painter.width - 0.1).ceilToDouble();
    painter.dispose();
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: width),
      child: Text(text, style: style, maxLines: 1, overflow: overflow, textAlign: TextAlign.left),
    );
  }
}
