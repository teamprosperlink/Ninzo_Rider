import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/profile_view_models.dart';
import '../widgets/profile_widgets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// Profile 04.
class MySpotPage extends ConsumerWidget {
  const MySpotPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mySpotViewModelProvider);
    final vm = ref.read(mySpotViewModelProvider.notifier);
    return ProfileScaffold(
      title: AppStrings.mySpot,
      onBack: vm.back,
      // Directions to the spot in Google Maps.
      bottom: RiderButton(AppStrings.navigateToSpot, onPressed: state == null ? null : vm.navigate),
      children: [
        _SpotMap(state?.spot ?? ''),
        const SizedBox(height: AppSizes.s16),
        ProfileCard(
          rows: [
            ProfileValueRow(AppStrings.spot, state?.spot ?? ''),
            ProfileValueRow(AppStrings.hub, state?.hub ?? ''),
            ProfileValueRow(AppStrings.distanceFromHub, state?.distance ?? ''),
            ProfileValueRow(AppStrings.assigned, state?.assigned ?? ''),
          ],
        ),
        const SizedBox(height: AppSizes.s16),
        Text(
          AppStrings.spotsAreSetByNinzoIf,
          style: RiderText.bodySmall.copyWith(color: RiderColors.grey),
        ),
      ],
    );
  }
}

/// The frame's flat "Spot map": pulse and dot in the middle, the label 44 left
/// of the middle.
class _SpotMap extends StatelessWidget {
  const _SpotMap(this.spot);

  final String spot;

  @override
  Widget build(BuildContext context) => Container(
    height: AppSizes.s160,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: RiderColors.spotMapFill, borderRadius: BorderRadius.circular(RiderRadius.field)),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final middle = constraints.maxWidth / 2;
        return Stack(
          children: [
            Positioned(
              left: middle - AppSizes.s36,
              top: AppSizes.s44,
              child: Container(
                width: AppSizes.s72,
                height: AppSizes.s72,
                decoration: const BoxDecoration(color: RiderColors.spotMapPulse, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              left: middle - AppSizes.s10,
              top: AppSizes.s70,
              child: Container(
                width: AppSizes.s20,
                height: AppSizes.s20,
                decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              left: middle - AppSizes.s44,
              top: AppSizes.s108,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.s12, vertical: AppSizes.s6),
                decoration: BoxDecoration(color: RiderColors.ink, borderRadius: BorderRadius.circular(RiderRadius.pill)),
                child: RiderHugText(spot, style: RiderText.labelMedium.copyWith(color: RiderColors.white)),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Profile 05. With no notifications the card has nothing to hold: no frame
/// draws that state.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(notificationsViewModelProvider);
    final vm = ref.read(notificationsViewModelProvider.notifier);
    return ProfileScaffold(
      title: AppStrings.notifications,
      onBack: vm.back,
      children: [
        if (lines.isNotEmpty)
          ProfileCard(
            rows: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.all(AppSizes.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(line.title, style: RiderText.labelLarge)),
                          RiderHugText(line.when, style: RiderText.captionSmall),
                        ],
                      ),
                      const SizedBox(height: AppSizes.s4),
                      Text(line.body, style: RiderText.bodySmall.copyWith(color: RiderColors.grey)),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Profile 06, "Last 7 days". No frame draws "Earlier" chosen, so it doesn't
/// switch; with no shifts the card has nothing to hold.
class MyShiftsPage extends ConsumerWidget {
  const MyShiftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(myShiftsViewModelProvider);
    final vm = ref.read(myShiftsViewModelProvider.notifier);
    return ProfileScaffold(
      title: AppStrings.myShifts,
      onBack: vm.back,
      children: [
        const ProfileSegments(labels: [AppStrings.last7Days, AppStrings.earlier], selected: 0),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: AppSizes.s16),
          ProfileCard(
            rows: [
              for (final line in lines) ProfileTwoLineRow(title: line.day, subtitle: line.detail, trailing: line.earned),
            ],
          ),
        ],
      ],
    );
  }
}

/// Profile 07. Read-only: the frame has nothing to edit with.
class YourProfilePage extends ConsumerWidget {
  const YourProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final header = ref.watch(profileHeaderProvider);
    final rows = ref.watch(yourProfileViewModelProvider);
    final vm = ref.read(yourProfileViewModelProvider.notifier);
    return ProfileScaffold(
      title: AppStrings.yourProfile,
      onBack: vm.back,
      children: [
        ProfileHeader(name: header.name, role: header.role),
        const SizedBox(height: AppSizes.s16),
        ProfileCard(rows: [for (final (label, value) in rows) ProfileValueRow(label, value)]),
      ],
    );
  }
}

/// Profile 08.
class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsViewModelProvider);
    final vm = ref.read(documentsViewModelProvider.notifier);
    return ProfileScaffold(
      title: AppStrings.documents,
      onBack: vm.back,
      children: [
        ProfileCard(
          rows: [
            for (final document in documents)
              Padding(
                padding: const EdgeInsets.all(AppSizes.s16),
                child: Row(
                  children: [
                    Expanded(child: Text(document.label, style: RiderText.labelLarge)),
                    // Keeps the row's height whichever way it's filled.
                    SizedBox(
                      height: AppSizes.s24,
                      child: document.verified
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSizes.s10, vertical: AppSizes.s4),
                              decoration: BoxDecoration(
                                color: RiderColors.nudgeTile,
                                borderRadius: BorderRadius.circular(RiderRadius.pill),
                              ),
                              child: RiderHugText(
                                AppStrings.verified,
                                style: RiderText.labelMedium.copyWith(color: RiderColors.brand),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
