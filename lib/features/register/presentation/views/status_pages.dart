import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/rider_application.dart';
import '../../domain/entities/rider_document.dart';
import '../viewmodels/register_view_model.dart';
import '../widgets/register_parts.dart';

/// Register 08–13: the application's review status.
class StatusPage extends ConsumerWidget {
  const StatusPage({super.key, required this.application, this.now});

  final RiderApplication application;

  /// For "Today, 2:14 PM"; defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(registerViewModelProvider);
    final vm = ref.read(registerViewModelProvider.notifier);
    final a = application;
    final busy = state.busy;
    return switch (a.status) {
      RegistrationStatus.approved when state.showSpot => RiderArtPage.status(
        art: const RiderArtTile.small(
          icon: Icons.verified_outlined,
          iconColor: RiderColors.white,
        ),
        overline: 'Your spot',
        title: 'You’ll ride from ${a.spotName ?? a.hubLabel ?? a.area.name}',
        body: 'This spot is assigned to you. Wait here for orders once you go online.',
        content: RiderInfoCard(
          children: [
            RiderInfoRow('Spot', value: a.spotName ?? ''),
            RiderInfoRow(
              'Distance from hub',
              value: a.spotDistanceKm == null
                  ? ''
                  : distance(a.spotDistanceKm!),
            ),
            const RiderInfoRow('We’ve notified you', value: 'On your phone'),
          ],
        ),
        actions: [RiderButton('Got it', loading: busy, onPressed: vm.finish)],
      ),
      RegistrationStatus.approved => RiderArtPage.status(
        art: const RiderArtTile.small(
          icon: Icons.verified_outlined,
          iconColor: RiderColors.white,
        ),
        overline: 'Welcome aboard',
        title: 'You’re approved, ${a.name.trim().split(' ').first}!',
        body: 'Your account is ready. Sign in with your mobile number to start your first shift.',
        content: RiderInfoCard(
          children: [
            RiderInfoRow('Hub', value: a.hubLabel ?? a.area.name),
            RiderInfoRow('First shift', value: a.firstShift ?? ''),
            const RiderInfoRow('Scooter', value: 'Assigned at the hub'),
          ],
        ),
        actions: [RiderButton('Sign in', onPressed: vm.showSpot)],
      ),
      RegistrationStatus.needsRetake => _issuesPage(
        icon: Icons.flip_camera_ios_outlined,
        overline: 'Action needed',
        title: a.issues.length == 1
            ? 'One document needs a retake'
            : '${a.issues.length} documents need a retake',
        // Figma draws one document; with more, the rest wait on the documents
        // screen, where the first retake leads.
        body: a.issues.length == 1
            ? 'Let’s get a clearer photo of your ${a.issues.first.$1.name}. '
                  'Take a new one and we’ll review it again.'
            : '',
        issueLabel: (_) => 'Retake',
        action: 'Retake ${a.issues.first.$1.name}',
        onAction: () => vm.fix(document: a.issues.first.$1),
        busy: busy,
      ),
      RegistrationStatus.failed => _issuesPage(
        icon: Icons.warning_amber_rounded,
        overline: 'Almost done',
        title:
            'Let’s fix ${a.issues.length} ${a.issues.length == 1 ? 'detail' : 'details'}',
        body: '${_failedSummary(a)} Upload them again and we’ll check them.',
        issueLabel: (issue) => switch (issue) {
          DocumentIssue.nameMismatch => 'Name needs matching',
          DocumentIssue.expired => 'Expired',
          DocumentIssue.retake => 'Photo needs a retake',
        },
        action: 'Upload documents by hand',
        onAction: () => vm.fix(),
        busy: busy,
      ),
      RegistrationStatus.expired => _issuesPage(
        icon: Icons.schedule_rounded,
        overline: 'Document expired',
        title: 'Time to renew your ${_expired(a).name}',
        body:
            'Add your renewed ${_expired(a).renewName ?? _expired(a).name} to keep taking orders. '
            'Your other documents are all set.',
        issueLabel: (_) => 'Expired',
        action: 'Update ${_expired(a).name}',
        onAction: () => vm.fix(),
        busy: busy,
      ),
      _ => RiderArtPage.status(
        art: RiderArtTile.small(
          icon: Icons.hourglass_empty_rounded,
          tone: RiderColors.warning,
          innerColor: RiderColors.warning.withValues(alpha: 0.16),
          iconColor: RiderColors.white,
        ),
        overline: 'Step 3 of 3',
        title: 'Documents under review',
        body:
            'Our team will check them, usually within 24 hours. We’ll SMS you at ${phoneNumber(a.phone)}.',
        content: RiderInfoCard(
          children: [
            RiderInfoRow(
              'Submitted',
              value: a.submittedAt == null
                  ? ''
                  : _when(a.submittedAt!, now ?? DateTime.now()),
            ),
            RiderInfoRow('Hub', value: a.hubLabel ?? a.area.name),
            const RiderInfoRow(
              'Status',
              labelColor: RiderColors.ink,
              trailing: RiderStatusPill.chip(
                'Under review',
                color: RiderColors.warning,
                textColor: RiderColors.warningText,
              ),
            ),
          ],
        ),
        // The flow map has no target for Done: it does nothing, and the page
        // moves on by itself when the review result arrives (09, 11–13).
        actions: [RiderButton('Done', onPressed: () {})],
      ),
    };
  }

  Widget _issuesPage({
    required IconData icon,
    required String overline,
    required String title,
    required String body,
    required String Function(DocumentIssue) issueLabel,
    required String action,
    required VoidCallback onAction,
    required bool busy,
  }) {
    final issues = {for (final (d, issue) in application.issues) d: issue};
    return RiderArtPage.status(
      art: RiderArtTile.small(
        icon: icon,
        tone: RiderColors.error,
        innerColor: RiderColors.error,
        iconColor: RiderColors.white,
      ),
      overline: overline,
      overlineColor: RiderColors.error,
      title: title,
      body: body,
      content: RiderInfoCard(
        children: [
          for (final d in RiderDocument.values)
            RiderInfoRow(
              d.label,
              labelColor: RiderColors.ink,
              trailing: issues[d] == null
                  ? addedChip
                  : issueChip(issueLabel(issues[d]!)),
            ),
        ],
      ),
      actions: [RiderButton(action, loading: busy, onPressed: onAction)],
    );
  }

  static RiderDocument _expired(RiderApplication a) =>
      a.issues.where((i) => i.$2 == DocumentIssue.expired).firstOrNull?.$1 ??
      RiderDocument.drivingLicence;

  /// "Your name and one photo need a quick update."
  static String _failedSummary(RiderApplication a) {
    final name = a.issues.any((i) => i.$2 == DocumentIssue.nameMismatch);
    final photos = a.issues
        .where((i) => i.$2 != DocumentIssue.nameMismatch)
        .length;
    final photoText = photos == 1 ? 'one photo' : '$photos photos';
    if (name && photos > 0) {
      return 'Your name and $photoText need a quick update.';
    }
    if (name) return 'Your name needs a quick update.';
    return '${photoText[0].toUpperCase()}${photoText.substring(1)} ${photos == 1 ? 'needs' : 'need'} a quick update.';
  }

  /// "Today, 2:14 PM", "Yesterday, 9:05 AM" or "3 Nov, 2:14 PM".
  static String _when(DateTime t, DateTime now) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final time =
        '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${t.day} ${months[t.month - 1]}, $time';
  }
}
