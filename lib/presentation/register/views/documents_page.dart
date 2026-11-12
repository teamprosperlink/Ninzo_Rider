import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/rider_application.dart';
import '../../../domain/entities/rider_document.dart';
import '../viewmodels/register_view_model.dart';
import '../widgets/register_parts.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/rider_settings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

/// Register 04 (none added) and 07 (documents complete).
class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key, required this.application});

  final RiderApplication application;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(registerViewModelProvider.select((s) => s.busy));
    final vm = ref.read(registerViewModelProvider.notifier);
    final added = application.addedCount;
    final total = RiderDocument.values.length;
    return RegisterScaffold(
      title: AppStrings.documents,
      onBack: vm.editDetails,
      bottomNote: AppStrings.ofAdded(added, total),
      bottom: [
        RiderButton(
          AppStrings.submitForReview,
          loading: busy,
          onPressed: application.allAdded || busy ? vm.submit : null,
        ),
      ],
      children: [
        const RiderStepProgress(step: AppLimits.registerDocumentsStep, total: AppLimits.registerSteps, label: AppStrings.documents),
        RegisterHeading(
          AppStrings.addYourDocuments,
          AppStrings.clearPhotosOnlyNoGlareUsually(RiderSettings.current.verificationWithin.inHours),
        ),
        RiderInfoCard(
          children: [
            for (final d in RiderDocument.values)
              _DocumentRow(
                document: d,
                added: application.isAdded(d),
                onAdd: () => vm.addDocument(d),
              ),
          ],
        ),
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.added,
    required this.onAdd,
  });

  final RiderDocument document;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onAdd,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.s12),
      child: Row(
        children: [
          RiderIconTile(documentIcon(document)),
          const SizedBox(width: AppSizes.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.label, style: RiderText.labelLarge),
                const SizedBox(height: AppSizes.s2),
                Text(document.hint, style: RiderText.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.s12),
          added
              ? RiderStatusPill.added
              : const RiderStatusPill(
                  AppStrings.add,
                  dot: false,
                  tint: RiderColors.documentTint,
                ),
        ],
      ),
    ),
  );
}
