import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/problem_report.dart';
import '../viewmodels/problem_report_view_model.dart';
import 'order_result_pages.dart';

/// Report a problem: Problem 01, 02 with an option chosen, 03 once sent.
class ProblemReportPage extends ConsumerWidget {
  const ProblemReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(problemReportViewModelProvider);
    final vm = ref.read(problemReportViewModelProvider.notifier);
    if (state.sent) {
      return OrderResultPage(
        title: 'Report sent',
        body: 'Thanks for letting us know. Stay where you are and we’ll update you right here.',
        rows: const [],
        action: 'Back to order',
        onAction: vm.close,
      );
    }
    final kind = state.kind;
    return RiderScaffold(
      title: 'Report a problem',
      onBack: vm.close,
      backSize: 48,
      backBordered: true,
      headerPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      bottomToEdge: true,
      bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
      bottomPadding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      bottom: [
        RiderButton('Send report', onPressed: kind == null ? null : vm.send, loading: state.busy),
        if (kind == null)
          Text('Choose what’s happening to continue.', textAlign: TextAlign.center, style: RiderText.caption),
      ],
      children: [
        Text(
          'Pick what’s happening. We’ll sort it out right away, with no penalty.',
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        for (final option in ProblemKind.values) ...[
          const SizedBox(height: 12),
          RiderOptionCard(
            title: option.label,
            subtitle: option.hint,
            selected: option == kind,
            onTap: () => vm.choose(option),
          ),
        ],
      ],
    );
  }
}
