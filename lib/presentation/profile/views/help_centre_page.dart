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
import '../../../core/constants/app_numbers.dart';
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
                  // No arrow or frame on the flow map for this one; the hub's number is the button below.
                  ProfileTwoLineRow(title: AppStrings.hubManager, subtitle: hub == null ? '' : hubLine(hub)),
                  ProfileTwoLineRow(
                    title: AppStrings.sendFeedback,
                    subtitle: AppStrings.helpUsImproveTheApp,
                    onTap: () => _sendFeedback(context, vm),
                  ),
                ],
        ),
      ],
    );
  }
}

/// "Send feedback" (Profile 09): what the rider writes goes to `POST /riders/me/feedback`.
/// No frame draws it, so it is the plainest sheet the app's parts make.
Future<void> _sendFeedback(BuildContext context, HelpCentreViewModel vm) async {
  final text = TextEditingController();
  final messenger = ScaffoldMessenger.of(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s16, AppSizes.s16, AppSizes.s16 + MediaQuery.of(sheet).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppStrings.sendFeedback, style: RiderText.labelLarge),
          const SizedBox(height: AppSizes.s12),
          TextField(
            controller: text,
            autofocus: true,
            minLines: AppLimits.feedbackMinLines,
            maxLines: AppLimits.feedbackMaxLines,
            maxLength: AppLimits.feedbackMaxChars,
            decoration: const InputDecoration(hintText: AppStrings.feedbackHint),
          ),
          const SizedBox(height: AppSizes.s12),
          RiderButton(AppStrings.feedbackSend, onPressed: () async => Navigator.of(sheet).pop(await vm.sendFeedback(text.text))),
        ],
      ),
    ),
  );
  text.dispose();
  if (sent == null) return;
  messenger.showSnackBar(SnackBar(content: Text(sent ? AppStrings.feedbackThanks : AppStrings.feedbackFailed)));
}

/// A question; tapping it shows the answer under it.
class _QuestionRow extends StatefulWidget {
  const _QuestionRow(this.article);

  final HelpArticle article;

  @override
  State<_QuestionRow> createState() => _QuestionRowState();
}

class _QuestionRowState extends State<_QuestionRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => setState(() => _open = !_open),
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(widget.article.question, style: RiderText.labelLarge)),
              const SizedBox(width: AppSizes.s12),
              Icon(_open ? Icons.expand_less : Icons.expand_more, size: AppSizes.s20, color: RiderColors.grey),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: AppSizes.s8),
            Text(widget.article.answer, style: RiderText.caption),
          ],
        ],
      ),
    ),
  );
}
