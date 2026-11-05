import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/rider_document.dart';
import '../viewmodels/register_view_model.dart';
import '../widgets/register_parts.dart';

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
        RiderButton('Take photo', onPressed: vm.takePhoto),
        RiderButton.secondary(
          'Upload from gallery',
          onPressed: () => vm.takePhoto(fromGallery: true),
        ),
      ],
      children: [
        if (isCard)
          Text(
            'Place the card inside the frame. Keep it flat and avoid glare.',
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
          ),
        RiderViewfinder(caption: isCard ? 'Align the card inside the corners' : null, cornerStroke: 4),
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
        'PHOTO PREVIEW',
        style: RiderText.overline.copyWith(
          color: RiderColors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
    return RegisterScaffold(
      title: document.title(state.side!),
      onBack: vm.retake,
      bottom: [
        RiderButton(
          'Use this photo',
          loading: state.busy,
          loadingLabel: 'Uploading…',
          onPressed: vm.usePhoto,
        ),
        RiderButton.secondary(
          'Retake',
          onPressed: state.busy ? null : vm.retake,
        ),
      ],
      children: [
        if (document != RiderDocument.selfie)
          Text(
            'Can you read every line of text clearly?',
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
          ),
        Container(
          height: 300,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: RiderColors.photoPreview,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: RiderColors.shadow,
                offset: Offset(0, 2),
                blurRadius: 2.6,
              ),
            ],
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
          'Blurry or cut-off photos get rejected and delay your approval.',
        ),
      ],
    );
  }
}
