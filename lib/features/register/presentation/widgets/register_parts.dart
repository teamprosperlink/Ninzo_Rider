import 'package:flutter/material.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/rider_document.dart';

/// Page frame of the register screens: the 48px header with a hairline back
/// circle right under the status bar, 16px gutters and gaps, and the
/// actions 28px above the bottom of the 800px frame.
class RegisterScaffold extends StatelessWidget {
  const RegisterScaffold({
    super.key,
    required this.title,
    required this.onBack,
    required this.children,
    this.bottom = const [],
    this.bottomNote,
  });

  final String title;
  final VoidCallback onBack;

  /// Body content; 16px apart.
  final List<Widget> children;
  final List<Widget> bottom;
  final String? bottomNote;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) => didPop ? null : onBack(),
    child: RiderScaffold(
      title: title,
      onBack: onBack,
      headerPadding: RiderHeader.flowPadding,
      backSize: 48,
      backBordered: true,
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottom: bottom,
      bottomNote: bottomNote,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ],
    ),
  );
}

/// H4 title and grey body (Register 01, 04).
class RegisterHeading extends StatelessWidget {
  const RegisterHeading(this.title, this.body, {super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: RiderText.h4),
      const SizedBox(height: 8),
      Text(body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
    ],
  );
}

/// Placeholder glyphs for the document tiles ("Icon tile / card (replace)").
IconData documentIcon(RiderDocument d) => switch (d) {
  RiderDocument.aadhaar => Icons.credit_card_rounded,
  RiderDocument.drivingLicence => Icons.description_rounded,
  RiderDocument.vehicleRc => Icons.directions_car_filled_rounded,
  RiderDocument.selfie => Icons.emoji_emotions_rounded,
  RiderDocument.bank => Icons.account_balance_rounded,
};

/// "● Added" chip.
const addedChip = RiderStatusPill.chip('Added');

/// Red chip for a document the team sent back, e.g. "● Retake".
Widget issueChip(String label) =>
    RiderStatusPill.chip(label, color: RiderColors.error);
