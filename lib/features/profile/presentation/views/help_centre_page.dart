import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/launcher.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../domain/usecases/profile_usecases.dart';
import '../viewmodels/profile_view_models.dart';
import '../widgets/profile_widgets.dart';

/// Profile 02 (FAQ) and 09 (Contact us).
class HelpCentrePage extends ConsumerWidget {
  const HelpCentrePage({super.key, required this.shift});

  final Shift shift;

  static const _questions = [
    'How do I go online?',
    'How do I load stock at the hub?',
    'Customer isn’t at the gate. What now?',
    'How are my earnings counted?',
    'How do I change my shift hours?',
    'Scooter has a fault. Who do I call?',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(helpCentreViewModelProvider);
    final vm = ref.read(helpCentreViewModelProvider.notifier);
    final phone = shift.hub.managerPhone;
    return ProfileScaffold(
      title: 'Help centre',
      onBack: vm.back,
      bottom: RiderButton.secondary(
        'Call hub manager',
        onPressed: () {
          if (phone != null) callPhone(phone);
        },
      ),
      children: [
        ProfileSegments(
          labels: const ['FAQ', 'Contact us'],
          selected: tab.index,
          onSelected: (i) => vm.show(HelpTab.values[i]),
        ),
        const SizedBox(height: 16),
        ProfileCard(
          rows: tab == HelpTab.faq
              ? [for (final question in _questions) _QuestionRow(question)]
              : [
                  ProfileTwoLineRow(
                    title: 'Report a problem',
                    subtitle: 'Tell us what’s happening',
                    onTap: vm.reportProblem,
                  ),
                  // No arrow or frame on the flow map for these two.
                  ProfileTwoLineRow(title: 'Hub manager', subtitle: hubLine(shift.hub)),
                  const ProfileTwoLineRow(title: 'Send feedback', subtitle: 'Help us improve the app'),
                ],
        ),
      ],
    );
  }
}

/// A question with its chevron. No frame draws an answer.
class _QuestionRow extends StatelessWidget {
  const _QuestionRow(this.question);

  final String question;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(child: Text(question, style: RiderText.labelLarge)),
        const SizedBox(width: 12),
        const Icon(Icons.expand_more, size: 20, color: RiderColors.grey),
      ],
    ),
  );
}
