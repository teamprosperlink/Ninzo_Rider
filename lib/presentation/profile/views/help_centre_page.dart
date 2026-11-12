import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/launcher.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/shift.dart';
import '../../../domain/usecases/profile_usecases.dart';
import '../../../domain/entities/profile.dart';
import '../providers/profile_providers.dart';
import '../viewmodels/profile_view_models.dart';
import '../widgets/profile_widgets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Profile 02 (FAQ) and 09 (Contact us).
class HelpCentrePage extends ConsumerWidget {
  const HelpCentrePage({super.key, required this.shift});

  /// Null on a day off.
  final Shift? shift;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(helpCentreViewModelProvider);
    final vm = ref.read(helpCentreViewModelProvider.notifier);
    final hub = shift?.hub;
    final phone = hub?.managerPhone;
    return ProfileScaffold(
      title: AppStrings.helpCentre,
      onBack: vm.back,
      bottom: RiderButton.secondary(
        AppStrings.callHubManager,
        onPressed: () {
          if (phone != null) callPhone(phone);
        },
      ),
      children: [
        ProfileSegments(
          labels: const [AppStrings.faq, AppStrings.contactUs],
          selected: tab.index,
          onSelected: (i) => vm.show(HelpTab.values[i]),
        ),
        const SizedBox(height: AppSizes.s16),
        ProfileCard(
          rows: tab == HelpTab.faq
              // The rider API's questions and answers (`GET /riders/me/help`).
              ? [for (final article in ref.watch(helpArticlesProvider).value ?? const <HelpArticle>[]) _QuestionRow(article)]
              : [
                  ProfileTwoLineRow(
                    title: AppStrings.reportAProblem,
                    subtitle: AppStrings.tellUsWhatSHappening,
                    onTap: vm.reportProblem,
                  ),
                  // No arrow or frame on the flow map for these two.
                  ProfileTwoLineRow(title: AppStrings.hubManager, subtitle: hub == null ? '' : hubLine(hub)),
                  const ProfileTwoLineRow(title: AppStrings.sendFeedback, subtitle: AppStrings.helpUsImproveTheApp),
                ],
        ),
      ],
    );
  }
}

/// A question with its chevron, from the rider API (`GET /riders/me/help`).
/// No frame draws an answer.
class _QuestionRow extends StatelessWidget {
  const _QuestionRow(this.article);

  final HelpArticle article;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSizes.s16),
    child: Row(
      children: [
        Expanded(child: Text(article.question, style: RiderText.labelLarge)),
        const SizedBox(width: AppSizes.s12),
        const Icon(Icons.expand_more, size: AppSizes.s20, color: RiderColors.grey),
      ],
    ),
  );
}
