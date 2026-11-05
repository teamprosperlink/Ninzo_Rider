import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/rider/rider_ui.dart';
import '../viewmodels/profile_view_models.dart';
import '../widgets/profile_widgets.dart';

/// Profile 04.
class MySpotPage extends ConsumerWidget {
  const MySpotPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mySpotViewModelProvider);
    final vm = ref.read(mySpotViewModelProvider.notifier);
    return ProfileScaffold(
      title: 'My spot',
      onBack: vm.back,
      // No arrow on the flow map.
      bottom: RiderButton('Navigate to spot', onPressed: () {}),
      children: [
        _SpotMap(state?.spot ?? ''),
        const SizedBox(height: 16),
        ProfileCard(
          rows: [
            ProfileValueRow('Spot', state?.spot ?? ''),
            ProfileValueRow('Hub', state?.hub ?? ''),
            ProfileValueRow('Distance from hub', state?.distance ?? ''),
            ProfileValueRow('Assigned', state?.assigned ?? ''),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Spots are set by Ninzo. If your spot changes, we’ll send you a notification.',
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
    height: 160,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: RiderColors.spotMapFill, borderRadius: BorderRadius.circular(RiderRadius.field)),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final middle = constraints.maxWidth / 2;
        return Stack(
          children: [
            Positioned(
              left: middle - 36,
              top: 44,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: RiderColors.spotMapPulse, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              left: middle - 10,
              top: 70,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(color: RiderColors.brand, shape: BoxShape.circle),
              ),
            ),
            Positioned(
              left: middle - 44,
              top: 108,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      title: 'Notifications',
      onBack: vm.back,
      children: [
        if (lines.isNotEmpty)
          ProfileCard(
            rows: [
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(line.title, style: RiderText.labelLarge)),
                          RiderHugText(line.when, style: RiderText.captionSmall),
                        ],
                      ),
                      const SizedBox(height: 4),
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
      title: 'My shifts',
      onBack: vm.back,
      children: [
        const ProfileSegments(labels: ['Last 7 days', 'Earlier'], selected: 0),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 16),
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
      title: 'Your profile',
      onBack: vm.back,
      children: [
        ProfileHeader(name: header.name, role: header.role),
        const SizedBox(height: 16),
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
      title: 'Documents',
      onBack: vm.back,
      children: [
        ProfileCard(
          rows: [
            for (final document in documents)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: Text(document.label, style: RiderText.labelLarge)),
                    // Keeps the row's height whichever way it's filled.
                    SizedBox(
                      height: 24,
                      child: document.verified
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: RiderColors.nudgeTile,
                                borderRadius: BorderRadius.circular(RiderRadius.pill),
                              ),
                              child: RiderHugText(
                                'Verified',
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
