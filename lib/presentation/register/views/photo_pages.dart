import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/rider_document.dart';
import '../viewmodels/register_view_model.dart';
import '../widgets/register_parts.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Register 05: how to frame the photo, then the camera or the gallery.
class PhotoPage extends ConsumerWidget {
  const PhotoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(registerViewModelProvider);
    final vm = ref.read(registerViewModelProvider.notifier);
    final document = state.photoDocument!;
    // Figma draws this screen for a card only (Aadhaar).
    final isCard = document != RiderDocument.selfie && document != RiderDocument.bank;
    return RegisterScaffold(
      title: document.title(state.side!),
      onBack: vm.backToDocuments,
      bottom: [
        RiderButton(AppStrings.takePhoto, onPressed: vm.takePhoto),
        RiderButton.secondary(
          AppStrings.uploadFromGallery,
          onPressed: () => vm.takePhoto(fromGallery: true),
        ),
      ],
      children: [
        if (isCard)
          Text(
            AppStrings.placeTheCardInsideTheFrame,
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
          ),
        RiderViewfinder(caption: isCard ? AppStrings.alignTheCardInsideTheCorners : null, cornerStroke: AppSizes.s4),
      ],
    );
  }
}

/// Register 06: check the photo, use it or take it again.
class PhotoReviewPage extends ConsumerWidget {
  const PhotoReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(registerViewModelProvider);
    final vm = ref.read(registerViewModelProvider.notifier);
    final document = state.photoDocument!;
    final path = state.photoPath;
    final placeholder = Center(
      child: Text(
        AppStrings.photoPreview,
        style: RiderText.overlineSpaced1_2.copyWith(color: RiderColors.grey),
      ),
    );
    return RegisterScaffold(
      title: document.title(state.side!),
      onBack: vm.retake,
      bottom: [
        RiderButton(
          AppStrings.useThisPhoto,
          loading: state.busy,
          loadingLabel: AppStrings.uploading,
          onPressed: vm.usePhoto,
        ),
        RiderButton.secondary(
          AppStrings.retake,
          onPressed: state.busy ? null : vm.retake,
        ),
      ],
      children: [
        if (document != RiderDocument.selfie)
          Text(
            AppStrings.canYouReadEveryLineOf,
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
          ),
        Container(
          height: AppSizes.s300,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: RiderColors.photoPreview,
            borderRadius: BorderRadius.circular(AppSizes.s24),
            boxShadow: RiderLayout.shadowShadow2x2_6,
          ),
          child: path == null
              ? placeholder
              : Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
        const RiderTip(
          AppStrings.blurryOrCutOffPhotosGet,
        ),
      ],
    );
  }
}
