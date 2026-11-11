import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/problem_report.dart';
import '../viewmodels/problem_report_view_model.dart';
import 'order_result_pages.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Report a problem: Problem 01, 02 with an option chosen, 03 once sent.
class ProblemReportPage extends ConsumerWidget {
  const ProblemReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(problemReportViewModelProvider);
    final vm = ref.read(problemReportViewModelProvider.notifier);
    if (state.sent) {
      return OrderResultPage(
        title: AppStrings.reportSent,
        body: AppStrings.thanksForLettingUsKnowStay,
        rows: const [],
        action: AppStrings.backToOrder,
        onAction: vm.close,
      );
    }
    final kind = state.kind;
    return RiderScaffold(
      title: AppStrings.reportAProblem,
      onBack: vm.close,
      backSize: AppSizes.s48,
      backBordered: true,
      headerPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s12),
      bottomToEdge: true,
      bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s12, AppSizes.s16, AppSizes.s24),
      bottom: [
        RiderButton(AppStrings.sendReport, onPressed: kind == null ? null : vm.send, loading: state.busy),
        if (kind == null)
          Text(AppStrings.chooseWhatSHappeningToContinue, textAlign: TextAlign.center, style: RiderText.caption),
      ],
      children: [
        Text(
          AppStrings.pickWhatSHappeningWeLl,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        for (final option in ProblemKind.values) ...[
          const SizedBox(height: AppSizes.s12),
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
