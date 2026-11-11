import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'rider_status.dart';
import '../../constants/app_strings.dart';
import '../../constants/app_sizes.dart';
import 'rider_refill.dart';
import '../../constants/app_numbers.dart';

/// 176px rounded art tile from the permission and status pages: a tinted
/// square with two soft circles and a white disc holding an icon.
/// Stand-in for the illustrations ("Art tile (replace illustration)").
class RiderArtTile extends StatelessWidget {
  /// The pause glyph on the break pages.
  static const pause = RiderArtTile.medium(glyph: RiderPauseGlyph());

  const RiderArtTile({super.key, required this.icon, this.tone = RiderColors.brand, this.iconColor, this.innerColor})
    : size = AppSizes.s176,
      discSize = AppSizes.s96,
      innerSize = AppSizes.s60,
      iconSize = AppSizes.s32,
      radius = AppSizes.s48,
      glyph = null,
      decor = _largeDecor;

  /// The 132px tile of the register status pages (Register 08–13).
  const RiderArtTile.small({
    super.key,
    required this.icon,
    this.tone = RiderColors.brand,
    this.iconColor,
    this.innerColor,
  }) : size = AppSizes.s132,
       discSize = AppSizes.s76,
       innerSize = AppSizes.s46,
       iconSize = AppSizes.s24,
       radius = AppSizes.s36,
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
  }) : size = AppSizes.s128,
       discSize = AppSizes.s72,
       innerSize = AppSizes.s0,
       innerColor = null,
       iconSize = AppSizes.s20,
       radius = AppSizes.s36,
       decor = const [(AppSizes.s70, -AppSizes.s24, AppSizes.s90), (-AppSizes.s14, AppSizes.s86, AppSizes.s60)];

  static const _largeDecor = [(AppSizes.s100_0, -AppSizes.s30_0, AppSizes.s120_0), (-AppSizes.s20_0, AppSizes.s120_0, AppSizes.s80_0)];

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
      RiderColors.error => (RiderColors.errorFill, RiderColors.errorHaloInner, RiderColors.errorHaloCore),
      RiderColors.warning => (RiderColors.tipFill, RiderColors.warningHaloInner, RiderColors.warningBanner),
      _ => (RiderColors.optionSelected, RiderColors.brandHaloInner, tone.withValues(alpha: AppOpacity.o0_1)),
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
                innerSize == AppSizes.s0
                    ? RiderLayout.artTileTintShadow
                    : RiderLayout.artTileShadow,
              ],
            ),
            child:
                glyph ??
                (innerSize == AppSizes.s0
                    // The design's icon sits a little up and left of the disc's centre.
                    ? Transform.translate(
                        offset: const Offset(-AppSizes.s4, -AppSizes.s3_5),
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
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppSizes.s4_5)),
    );
    return Stack(alignment: Alignment.center, children: [bar(AppSizes.s28, AppSizes.s9), bar(AppSizes.s9, AppSizes.s28)]);
  }
}

/// The 104px Ninzo app mark: glossy green tile, speed lines and "N".
/// Stand-in for the final logo ("Logo mark (replace)").
class RiderLogoMark extends StatelessWidget {
  const RiderLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    Widget speedLine(double top, double width) => Positioned(
      left: AppSizes.s12_67,
      top: top - AppSizes.s0_17,
      child: Container(
        width: width,
        height: AppSizes.s3_5,
        decoration: BoxDecoration(color: RiderColors.white, borderRadius: BorderRadius.circular(RiderRadius.pill)),
      ),
    );
    return Container(
      width: AppSizes.s104,
      height: AppSizes.s104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.s32),
        border: Border.all(color: RiderColors.white.withValues(alpha: AppOpacity.o0_35), width: AppSizes.s1_5),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [RiderColors.heroGradientStart, RiderColors.heroGradientEnd],
        ),
        boxShadow: RiderLayout.brand40Shadow18x30_3,
      ),
      child: Stack(
        children: [
          Positioned(
            left: -AppSizes.s27,
            top: -AppSizes.s51,
            child: Container(
              width: AppSizes.s150,
              height: AppSizes.s80,
              decoration: BoxDecoration(
                color: RiderColors.white.withValues(alpha: AppOpacity.o0_12),
                borderRadius: const BorderRadius.all(Radius.elliptical(AppSizes.s75, AppSizes.s40)),
              ),
            ),
          ),
          speedLine(AppSizes.s38_5, AppSizes.s16),
          speedLine(AppSizes.s48_5, AppSizes.s24),
          speedLine(AppSizes.s58_5, AppSizes.s14),
          Positioned(
            left: AppSizes.s43,
            top: AppSizes.s14,
            child: Text(
              AppStrings.textN,
              style: RiderText.heroNumber,
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
      width: AppSizes.s40,
      height: AppSizes.s40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RiderRadius.field),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [RiderColors.tileGradientStart, RiderColors.tileGradientEnd],
        ),
        border: const Border(
          top: BorderSide(color: RiderColors.brand14),
          left: BorderSide(color: RiderColors.brand14),
          right: BorderSide(color: RiderColors.brand14),
          bottom: BorderSide(color: RiderColors.brand14, width: AppSizes.s2),
        ),
      ),
      child: Container(
        width: AppSizes.s24,
        height: AppSizes.s24,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment(-AppSizes.s1_08, -AppSizes.s1_08),
            end: Alignment(AppSizes.s0_68, AppSizes.s0_68),
            colors: [RiderColors.badgeGradientStart, RiderColors.badgeGradientEnd],
          ),
          boxShadow: RiderLayout.brand30Shadow3x4_33,
        ),
        child: const Icon(Icons.check, size: AppSizes.s16, color: RiderColors.white),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s4),
      decoration: BoxDecoration(
        color: RiderColors.white,
        borderRadius: BorderRadius.circular(RiderRadius.card),
        border: Border.all(color: RiderColors.hairline),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: AppSizes.s1, thickness: AppSizes.s1, color: RiderColors.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.s12),
              child: Row(
                children: [
                  const RiderTickTile(),
                  const SizedBox(width: AppSizes.s12),
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
    this.padding = const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s24, AppSizes.s16, AppSizes.s16),
    this.gap = AppSizes.s20,
    this.actionsPadding = const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s8),
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
       padding = const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s16),
       gap = AppSizes.s16,
       actionsPadding = const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12);

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
                        padding: const EdgeInsets.only(left: AppSizes.s1_2),
                        child: Text(
                          overline.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: RiderText.overlineSpaced1_2.copyWith(color: overlineColor),
                        ),
                      ),
                      const SizedBox(height: AppSizes.s8),
                      Text(title, textAlign: TextAlign.center, style: titleStyle ?? RiderText.h4),
                      const SizedBox(height: AppSizes.s8),
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
                      for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: AppSizes.s8), actions[i]],
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
