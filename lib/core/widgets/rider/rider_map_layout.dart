import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/rider_tokens.dart';

/// Map screens from the design: a map filling the top, overlays on it, and a
/// white bottom sheet (32 radius, grey handle) holding the content.
class RiderMapLayout extends StatelessWidget {
  const RiderMapLayout({
    super.key,
    required Widget this.map,
    required this.sheet,
    this.overlays = const [],
  }) : mapBuilder = null,
       customSheet = null,
       floating = const [];

  /// The map also runs under the sheet's rounded corners. [mapBuilder] gets
  /// the map's height, to place things on it by pixel; [customSheet] replaces
  /// the [RiderSheet] of [sheet]; [floating] are extras over the map.
  const RiderMapLayout.underSheet({
    super.key,
    required Widget Function(double height) this.mapBuilder,
    this.sheet = const [],
    this.customSheet,
    this.overlays = const [],
    this.floating = const [],
  }) : map = null;

  /// How far the map runs under the sheet.
  static const underSheetOverlap = 36.0;

  /// Usually a [MapView]; the design's grey blocks are a map placeholder.
  final Widget? map;
  final Widget Function(double height)? mapBuilder;

  /// Content of the bottom sheet, laid out top to bottom.
  final List<Widget> sheet;
  final Widget? customSheet;

  /// Widgets placed over the map (turn card, alerts), top aligned.
  final List<Widget> overlays;
  final List<Widget> floating;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarDark,
      child: Scaffold(
        backgroundColor: RiderColors.screen,
        body: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (mapBuilder != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: -underSheetOverlap,
                        child: mapBuilder!(constraints.maxHeight + underSheetOverlap),
                      )
                    else
                      Positioned.fill(child: map!),
                    if (overlays.isNotEmpty)
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < overlays.length; i++) ...[
                                if (i > 0) const SizedBox(height: 8),
                                overlays[i],
                              ],
                            ],
                          ),
                        ),
                      ),
                    ...floating,
                  ],
                ),
              ),
            ),
            customSheet ?? RiderSheet(children: sheet),
          ],
        ),
      ),
    );
  }
}

/// The white rounded sheet with a handle; also used for modal sheets.
class RiderSheet extends StatelessWidget {
  const RiderSheet({super.key, required this.children, this.gap = 16, this.bottomGap = 12, this.minHeight = 0});

  final List<Widget> children;
  final double gap;

  /// Below the content, above the gesture area.
  final double bottomGap;

  /// Keeps the sheet this tall with room to spare (Order 03).
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      decoration: const BoxDecoration(
        color: RiderColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RiderRadius.sheet),
        ),
        boxShadow: riderShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      // 28px below the content in the 800px frame: 12 above the gesture
      // area, which the system inset covers.
      child: Padding(
        padding: EdgeInsets.only(
          bottom: bottomGap + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: RiderColors.divider,
                  borderRadius: BorderRadius.circular(RiderRadius.pill),
                ),
              ),
            ),
            for (final child in children) ...[SizedBox(height: gap), child],
          ],
        ),
      ),
    );
  }
}

/// The sheet of Shift 28: a fixed-height scrolling area and a fixed bar below
/// it holding the action.
class RiderScrollSheet extends StatelessWidget {
  const RiderScrollSheet({super.key, required this.children, required this.bottom, this.scrollHeight = 356});

  final List<Widget> children;
  final Widget bottom;
  final double scrollHeight;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: RiderColors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(RiderRadius.sheet)),
      boxShadow: riderShadow,
    ),
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: RiderColors.divider, borderRadius: BorderRadius.circular(RiderRadius.pill)),
          ),
        ),
        SizedBox(
          height: scrollHeight,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
              ],
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
          decoration: const BoxDecoration(
            color: RiderColors.white,
            boxShadow: [BoxShadow(color: Color(0x0F000000), offset: Offset(0, -4), blurRadius: 9.5)],
          ),
          child: bottom,
        ),
      ],
    ),
  );
}

/// Opens [children] in a modal [RiderSheet].
Future<T?> showRiderSheet<T>(
  BuildContext context, {
  required List<Widget> Function(BuildContext) builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => RiderSheet(children: builder(context)),
);

/// White card floating on the map: "In 300 m, turn left".
class RiderMapCard extends StatelessWidget {
  const RiderMapCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RiderColors.white,
        borderRadius: BorderRadius.circular(RiderRadius.m),
        boxShadow: const [
          BoxShadow(
            color: RiderColors.shadow,
            offset: Offset(0, 2),
            blurRadius: 2.6,
          ),
        ],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: RiderText.labelLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: RiderText.caption),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Black rounded label on the map ("You're here", "Gate 3").
class RiderMapLabel extends StatelessWidget {
  const RiderMapLabel(this.text, {super.key, this.inverse = false});

  final String text;

  /// White label with ink text (distance chips).
  final bool inverse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: inverse
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: inverse ? RiderColors.white : RiderColors.ink,
        borderRadius: BorderRadius.circular(RiderRadius.pill),
        boxShadow: inverse ? riderShadow : null,
      ),
      child: Text(
        text,
        style: RiderText.labelSmall.copyWith(
          color: inverse ? RiderColors.ink : RiderColors.white,
        ),
      ),
    );
  }
}

/// Destination marker: a 22px green dot with a white ring inside a soft
/// 64px pulse (hub, spot).
class RiderMapPlaceDot extends StatelessWidget {
  const RiderMapPlaceDot({super.key, this.size = 64, this.pulseAlpha = 0.15});

  /// Of the pulse; 60 on the order map.
  final double size;
  final double pulseAlpha;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: RiderColors.brand.withValues(alpha: pulseAlpha), shape: BoxShape.circle),
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: RiderColors.brand,
        shape: BoxShape.circle,
        border: Border.all(color: RiderColors.white, width: 3),
      ),
    ),
  );
}

/// The rider's position: an 18px ink dot with a white ring.
class RiderMapYouDot extends StatelessWidget {
  const RiderMapYouDot({super.key});

  static const size = 18.0;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: RiderColors.ink,
      shape: BoxShape.circle,
      border: Border.all(color: RiderColors.white, width: 3),
    ),
  );
}

/// A named place on the map: its dot in the pulse with the black label above
/// ("Hub 2", "Yelahanka Node"; centred for "You're here").
class RiderMapPlaceMarker extends StatelessWidget {
  const RiderMapPlaceMarker(this.label, {super.key, this.centered = false, this.pulse = 64, this.pulseAlpha = 0.15});

  /// The marker's size; its centre is the place.
  static const width = 144.0, height = 136.0;

  final String label;
  final bool centered;
  final double pulse;
  final double pulseAlpha;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Stack(
      children: [
        Positioned(
          left: (width - pulse) / 2,
          top: (height - pulse) / 2,
          child: RiderMapPlaceDot(size: pulse, pulseAlpha: pulseAlpha),
        ),
        if (centered)
          Positioned(left: 0, right: 0, top: 6, child: Center(child: RiderMapLabel(label)))
        else
          Positioned(left: 10, top: 6, child: RiderMapLabel(label)),
      ],
    ),
  );
}

/// The rider's dot with a white chip below ("1.2 km", "You").
class RiderMapYouMarker extends StatelessWidget {
  const RiderMapYouMarker(this.label, {super.key, this.labelLeft = 33});

  /// The marker's size; its centre is the rider.
  static const width = 120.0, height = 80.0;

  final String label;

  /// Where the chip starts; the dot's left edge is at 51.
  final double labelLeft;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Stack(
      children: [
        const Positioned(left: 51, top: 31, child: RiderMapYouDot()),
        if (label.isNotEmpty) Positioned(left: labelLeft, top: 54, child: RiderMapLabel(label, inverse: true)),
      ],
    ),
  );
}

/// The rider on the order map: a 34px black puck with a white centre and the
/// distance chip under it (Order 01–03, Navigate 01–03).
class RiderMapRiderPuck extends StatelessWidget {
  const RiderMapRiderPuck(this.label, {super.key});

  /// The marker's size; its centre is the rider.
  static const width = 120.0, height = 110.0;
  static const _puck = 34.0;

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Stack(
      children: [
        Positioned(
          left: (width - _puck) / 2,
          top: (height - _puck) / 2,
          child: Container(
            width: _puck,
            height: _puck,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: RiderColors.ink,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: RiderColors.shadow, offset: Offset(0, 2), blurRadius: 2.6)],
            ),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: RiderColors.white, shape: BoxShape.circle),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: (height - _puck) / 2 + 39,
          child: Center(child: RiderMapLabel(label, inverse: true)),
        ),
      ],
    ),
  );
}

/// The dashed delivery radius around a gate (Order 01–03, Navigate 01–03).
class RiderDeliveryRadius extends StatelessWidget {
  const RiderDeliveryRadius({super.key});

  /// Drawn at this size whatever the map's zoom, as designed.
  static const size = 240.0;

  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: size, child: CustomPaint(painter: _DashedCirclePainter()));
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 0.75;
    canvas.drawCircle(center, size.width / 2, Paint()..color = RiderColors.brand.withValues(alpha: 0.07));
    final dash = Paint()
      ..color = RiderColors.brand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dashLength = 6.0, gapLength = 4.0;
    final count = (2 * math.pi * radius / (dashLength + gapLength)).floor();
    final sweep = 2 * math.pi / count;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, i * sweep, sweep * dashLength / (dashLength + gapLength), false, dash);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) => false;
}

/// 40px tinted tile with the turn arrow, for a [RiderMapCard].
class RiderTurnTile extends StatelessWidget {
  const RiderTurnTile({super.key, this.left = false, this.radius = RiderRadius.m, this.arrowHeight = 18, this.stroke = 2.5});

  /// The order map's tile (Order 01–03, Navigate 01–03).
  const RiderTurnTile.order({super.key, this.left = false}) : radius = 10, arrowHeight = 18, stroke = 2.5;

  final bool left;
  final double radius;
  final double arrowHeight;
  final double? stroke;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: RiderColors.brandTint, borderRadius: BorderRadius.circular(radius)),
    // The design's right-turn arrow sits off centre; its left-turn arrow is shorter.
    child: Transform.translate(
      offset: left ? const Offset(0, 1.17) : const Offset(-4, -1.83),
      child: RiderTurnRightIcon(
        color: RiderColors.brand,
        height: left ? arrowHeight - 2 : arrowHeight,
        left: left,
        stroke: stroke,
      ),
    ),
  );
}

/// The design's turn arrow (Shift 21, 52): up, then right with a head; [left]
/// mirrors it (Shift 22).
class RiderTurnRightIcon extends StatelessWidget {
  const RiderTurnRightIcon({super.key, this.color = RiderColors.white, this.height = 17, this.left = false, this.stroke});

  final Color color;
  final double height;
  final bool left;

  /// Line width; scales with [height] when unset.
  final double? stroke;

  @override
  Widget build(BuildContext context) => Transform.flip(
    flipX: left,
    child: SizedBox(
      width: height * 12 / 17,
      height: height,
      child: CustomPaint(painter: _TurnRightPainter(color, stroke)),
    ),
  );
}

class _TurnRightPainter extends CustomPainter {
  const _TurnRightPainter(this.color, this.stroke);

  final Color color;
  final double? stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 12, y = size.height / 17;
    canvas.drawPath(
      Path()
        ..moveTo(x, 16.5 * y)
        ..lineTo(x, 5.5 * y)
        ..lineTo(11 * x, 5.5 * y)
        ..moveTo(6.5 * x, y)
        ..lineTo(11 * x, 5.5 * y)
        ..lineTo(6.5 * x, 10 * y),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke ?? 2.2 * y
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TurnRightPainter old) => old.color != color || old.stroke != stroke;
}
