import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/rider_tokens.dart';
import 'rider_status.dart';

/// 176px rounded art tile from the permission and status pages: a tinted
/// square with two soft circles and a white disc holding an icon.
/// Stand-in for the illustrations ("Art tile (replace illustration)").
class RiderArtTile extends StatelessWidget {
  const RiderArtTile({super.key, required this.icon, this.tone = RiderColors.brand, this.iconColor, this.innerColor})
    : size = 176,
      discSize = 96,
      innerSize = 60,
      iconSize = 32,
      radius = 48,
      glyph = null,
      decor = _largeDecor;

  /// The 132px tile of the register status pages (Register 08–13).
  const RiderArtTile.small({
    super.key,
    required this.icon,
    this.tone = RiderColors.brand,
    this.iconColor,
    this.innerColor,
  }) : size = 132,
       discSize = 76,
       innerSize = 46,
       iconSize = 24,
       radius = 36,
       glyph = null,
       decor = _largeDecor;

  /// The 128px tile of the Home empty states (Shift 51 "Load stock at the
  /// hub"): a white 72px disc holding the icon, no inner circle.
  const RiderArtTile.medium({
    super.key,
    this.icon = Icons.circle,
    this.tone = RiderColors.brand,
    this.iconColor,
    this.glyph,
  }) : size = 128,
       discSize = 72,
       innerSize = 0,
       innerColor = null,
       iconSize = 20,
       radius = 36,
       decor = const [(70, -24, 90), (-14, 86, 60)];

  static const _largeDecor = [(100.0, -30.0, 120.0), (-20.0, 120.0, 80.0)];

  final IconData icon;

  /// Drawn in the disc's centre instead of [icon] (Shift 33's plus).
  final Widget? glyph;

  /// Colour the tile and circles are tinted with (brand or error).
  final Color tone;

  /// Defaults to [tone].
  final Color? iconColor;

  /// Fill of the inner disc behind the icon; defaults to [tone] at 10%.
  final Color? innerColor;

  final double size;
  final double discSize;
  final double innerSize;
  final double iconSize;
  final double radius;

  /// The two soft circles: (left, top, diameter).
  final List<(double, double, double)> decor;

  @override
  Widget build(BuildContext context) {
    final (tile, circle, inner) = switch (tone) {
      RiderColors.error => (const Color(0xFFF9E8E8), const Color(0xFFF9DBDB), const Color(0xFFFDE8E8)),
      RiderColors.warning => (const Color(0xFFF9EFDD), const Color(0xFFFAEACD), const Color(0xFFFDF3E1)),
      _ => (const Color(0xFFE4F2E4), const Color(0xFFD3ECD3), tone.withValues(alpha: 0.1)),
    };
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(radius)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final (left, top, d) in decor) Positioned(left: left, top: top, child: _circle(d, circle)),
          Container(
            width: discSize,
            height: discSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RiderColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                innerSize == 0
                    ? const BoxShadow(color: Color(0x1A009600), offset: Offset(0, 8), blurRadius: 16.5)
                    : const BoxShadow(color: RiderColors.shadow, offset: Offset(0, 8), blurRadius: 9.5),
              ],
            ),
            child:
                glyph ??
                (innerSize == 0
                    // The design's icon sits a little up and left of the disc's centre.
                    ? Transform.translate(
                        offset: const Offset(-4, -3.5),
                        child: Icon(icon, size: iconSize, color: iconColor ?? tone),
                      )
                    : Container(
                        width: innerSize,
                        height: innerSize,
                        decoration: BoxDecoration(color: innerColor ?? inner, shape: BoxShape.circle),
                        child: Icon(icon, size: iconSize, color: iconColor ?? tone),
                      )),
          ),
        ],
      ),
    );
  }

  static Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// The rounded plus on the Add time tile (Shift 33): two 28 × 9 bars.
class RiderPlusGlyph extends StatelessWidget {
  const RiderPlusGlyph({super.key, this.color = RiderColors.brand});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4.5)),
    );
    return Stack(alignment: Alignment.center, children: [bar(28, 9), bar(9, 28)]);
  }
}

/// The 104px Ninzo app mark: glossy green tile, speed lines and "N".
/// Stand-in for the final logo ("Logo mark (replace)").
class RiderLogoMark extends StatelessWidget {
  const RiderLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    Widget speedLine(double top, double width) => Positioned(
      left: 12.67,
      top: top - 0.17,
      child: Container(
        width: width,
        height: 3.5,
        decoration: BoxDecoration(color: RiderColors.white, borderRadius: BorderRadius.circular(RiderRadius.pill)),
      ),
    );
    return Container(
      width: 104,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: RiderColors.white.withValues(alpha: 0.35), width: 1.5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF33D138), Color(0xFF00800D)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66009600), offset: Offset(0, 18), blurRadius: 30.3)],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -27,
            top: -51,
            child: Container(
              width: 150,
              height: 80,
              decoration: BoxDecoration(
                color: RiderColors.white.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.elliptical(75, 40)),
              ),
            ),
          ),
          speedLine(38.5, 16),
          speedLine(48.5, 24),
          speedLine(58.5, 14),
          Positioned(
            left: 43,
            top: 14,
            child: Text(
              'N',
              style: RiderText.displayXl.copyWith(color: RiderColors.white, fontSize: 60, height: 68 / 60),
            ),
          ),
        ],
      ),
    );
  }
}

/// 40px pale-green tile with a raised green tick badge (benefit bullets).
class RiderTickTile extends StatelessWidget {
  const RiderTickTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RiderRadius.field),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDFCED), Color(0xFFCCF0D1)],
        ),
        border: const Border(
          top: BorderSide(color: Color(0x24009600)),
          left: BorderSide(color: Color(0x24009600)),
          right: BorderSide(color: Color(0x24009600)),
          bottom: BorderSide(color: Color(0x24009600), width: 2),
        ),
      ),
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment(-1.08, -1.08),
            end: Alignment(0.68, 0.68),
            colors: [Color(0xFF38CC3D), Color(0xFF00800F)],
          ),
          boxShadow: [BoxShadow(color: Color(0x4D009600), offset: Offset(0, 3), blurRadius: 4.33)],
        ),
        child: const Icon(Icons.check, size: 16, color: RiderColors.white),
      ),
    );
  }
}

/// White card listing benefits, each with a [RiderTickTile].
class RiderTickCard extends StatelessWidget {
  const RiderTickCard(this.items, {super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: RiderColors.white,
        borderRadius: BorderRadius.circular(RiderRadius.card),
        border: Border.all(color: RiderColors.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: RiderColors.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const RiderTickTile(),
                  const SizedBox(width: 12),
                  Expanded(child: Text(items[i], style: RiderText.bodyMedium)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full page from the permission / status designs: optional step bars, art
/// tile, centred overline + H4 title + grey body, a benefits card, and
/// actions pinned to the bottom.
class RiderArtPage extends StatelessWidget {
  const RiderArtPage({
    super.key,
    this.steps,
    required this.art,
    required this.overline,
    this.overlineColor = RiderColors.brand,
    required this.title,
    this.titleStyle,
    required this.body,
    this.benefits = const [],
    this.actions = const [],
    this.content,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 16),
    this.gap = 20,
    this.actionsPadding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  /// The register status pages (Register 08–13): the small art tile right
  /// under the status bar, 16px gaps, and a details card ([content]).
  const RiderArtPage.status({
    super.key,
    required this.art,
    required this.overline,
    this.overlineColor = RiderColors.brand,
    required this.title,
    required this.body,
    this.content,
    this.actions = const [],
  }) : steps = null,
       titleStyle = null,
       benefits = const [],
       padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
       gap = 16,
       actionsPadding = const EdgeInsets.fromLTRB(16, 8, 16, 12);

  /// (done, total) for the segmented bars at the top, e.g. (1, 3).
  final (int, int)? steps;
  final Widget art;
  final String overline;
  final Color overlineColor;
  final String title;

  /// Defaults to Heading/H4.
  final TextStyle? titleStyle;
  final String body;

  final List<String> benefits;

  /// Buttons, 8px apart.
  final List<Widget> actions;

  /// Shown below the body instead of (or after) the benefits card.
  final Widget? content;

  /// Around the scrolling content.
  final EdgeInsets padding;

  /// Space between the art, the text block and the card.
  final double gap;
  final EdgeInsets actionsPadding;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarDark,
      child: Scaffold(
        backgroundColor: RiderColors.screen,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: padding,
                  child: Column(
                    children: [
                      if (steps case (final done, final total)) ...[
                        RiderStepBars(total: total, done: done, inactive: RiderColors.ink, padding: EdgeInsets.zero),
                        SizedBox(height: gap),
                      ],
                      art,
                      SizedBox(height: gap),
                      // Flutter centres the spacing after the last letter too; Figma doesn't.
                      Padding(
                        padding: const EdgeInsets.only(left: 1.2),
                        child: Text(
                          overline.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: RiderText.overline.copyWith(color: overlineColor, letterSpacing: 1.2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(title, textAlign: TextAlign.center, style: titleStyle ?? RiderText.h4),
                      const SizedBox(height: 8),
                      Text(
                        body,
                        textAlign: TextAlign.center,
                        style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
                      ),
                      if (benefits.isNotEmpty) ...[SizedBox(height: gap), RiderTickCard(benefits)],
                      if (content != null) ...[SizedBox(height: gap), content!],
                    ],
                  ),
                ),
              ),
              if (actions.isNotEmpty)
                Padding(
                  padding: actionsPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: 8), actions[i]],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
