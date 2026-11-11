import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'rider_buttons.dart';
import '../../constants/app_sizes.dart';

/// Page frame used by the full-screen designs: #FBFBFB background, an
/// optional header (back circle + title + trailing action), scrolling body
/// with 16px side gutters, and actions pinned to the bottom.
class RiderScaffold extends StatelessWidget {
  const RiderScaffold({
    super.key,
    this.title,
    this.showBack = true,
    this.onBack,
    this.backIcon = Icons.arrow_back,
    this.trailing,
    this.top,
    required this.children,
    this.bottom = const [],
    this.bottomNote,
    this.background = RiderColors.screen,
    this.scrollable = true,
    this.bodyPadding = const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s16),
    this.headerPadding = RiderHeader.defaultPadding,
    this.backSize = AppSizes.s44,
    this.backBordered = false,
    this.bottomPadding = const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s16),
    this.bottomDecoration,
    this.bottomMargin = EdgeInsets.zero,
    this.bottomGap = AppSizes.s8,
    this.bottomToEdge = false,
  });

  /// Header title next to the back button (Subheading/Medium).
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final IconData backIcon;

  /// Right side of the header, e.g. a [RiderLink] or a status pill.
  final Widget? trailing;

  /// Full-width content above the body, below the header (e.g. step bars).
  final Widget? top;
  final List<Widget> children;

  /// Pinned actions, usually [RiderButton]s; [bottomGap] apart.
  final List<Widget> bottom;

  /// Small grey centred text above the pinned actions ("0 of 5 added").
  final String? bottomNote;
  final Color background;
  final bool scrollable;
  final EdgeInsets bodyPadding;

  /// Around the header row; [RiderHeader.flowPadding] for the 48px header
  /// of the register and document screens.
  final EdgeInsets headerPadding;

  /// Back button size; 48 with [backBordered] for the hairline variant.
  final double backSize;
  final bool backBordered;

  /// Around the pinned actions.
  final EdgeInsets bottomPadding;

  /// Background of the pinned actions, e.g. the white bar of Shift 53.
  final Decoration? bottomDecoration;

  /// Outside the pinned actions' background.
  final EdgeInsets bottomMargin;

  /// Between the pinned actions.
  final double bottomGap;

  /// The pinned actions' background runs to the screen's bottom edge, under
  /// the gesture bar (Stock 07, 08, 13, 14). [bottomPadding] then allows for
  /// the usual 16px gesture bar.
  final bool bottomToEdge;

  @override
  Widget build(BuildContext context) {
    final hasHeader = showBack || title != null || trailing != null;
    final body = Padding(
      padding: bodyPadding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
    final gestureBar = MediaQuery.viewPaddingOf(context).bottom;
    final actionsPadding = bottomToEdge
        ? bottomPadding + EdgeInsets.only(bottom: gestureBar > AppSizes.s16 ? gestureBar - AppSizes.s16 : AppSizes.s0)
        : bottomPadding;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: riderStatusBarDark,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: !bottomToEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasHeader)
                RiderHeader(
                  title: title,
                  showBack: showBack,
                  onBack: onBack,
                  backIcon: backIcon,
                  trailing: trailing,
                  padding: headerPadding,
                  backSize: backSize,
                  backBordered: backBordered,
                ),
              ?top,
              Expanded(child: scrollable ? SingleChildScrollView(child: body) : body),
              if (bottom.isNotEmpty || bottomNote != null)
                Container(
                  margin: bottomMargin,
                  decoration: bottomDecoration,
                  padding: actionsPadding,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (bottomNote != null) ...[
                        Text(bottomNote!, textAlign: TextAlign.center, style: RiderText.caption),
                        const SizedBox(height: AppSizes.s8),
                      ],
                      for (var i = 0; i < bottom.length; i++) ...[if (i > 0) SizedBox(height: bottomGap), bottom[i]],
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

/// Header row: back circle, title, trailing.
class RiderHeader extends StatelessWidget {
  const RiderHeader({
    super.key,
    this.title,
    this.showBack = true,
    this.onBack,
    this.backIcon = Icons.arrow_back,
    this.trailing,
    this.padding = defaultPadding,
    this.backSize = AppSizes.s44,
    this.backBordered = false,
  });

  static const defaultPadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s12);

  /// The register and document screens: the 48px row sits right under the
  /// status bar, 16px above the content.
  static const flowPadding = EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s16);

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final IconData backIcon;
  final Widget? trailing;
  final EdgeInsets padding;
  final double backSize;
  final bool backBordered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: backSize,
        child: Row(
          children: [
            if (showBack) RiderBackButton(onPressed: onBack, icon: backIcon, size: backSize, bordered: backBordered),
            if (showBack && title != null) const SizedBox(width: AppSizes.s16),
            if (title != null)
              Expanded(
                child: Text(title!, style: RiderText.subheadingMedium, overflow: TextOverflow.ellipsis),
              )
            else
              const Spacer(),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Title block: optional green overline, H4 heading, grey body.
class RiderTitleBlock extends StatelessWidget {
  const RiderTitleBlock({super.key, this.overline, required this.title, this.subtitle, this.center = false});

  final String? overline;
  final String title;
  final String? subtitle;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final align = center ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (overline != null) ...[
          // Flutter sets half the spacing before the first letter; Figma doesn't.
          Transform.translate(
            offset: Offset(center ? AppSizes.s0 : -RiderText.overline.letterSpacing! / AppSizes.s2, AppSizes.s0),
            child: Text(overline!.toUpperCase(), style: RiderText.overline, textAlign: align),
          ),
          const SizedBox(height: AppSizes.s8),
        ],
        Text(title, style: RiderText.h4, textAlign: align),
        if (subtitle != null) ...[
          const SizedBox(height: AppSizes.s8),
          Text(
            subtitle!,
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
            textAlign: align,
          ),
        ],
      ],
    );
  }
}
