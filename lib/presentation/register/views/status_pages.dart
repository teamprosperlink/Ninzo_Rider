import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/rider_application.dart';
import '../../../domain/entities/rider_document.dart';
import '../viewmodels/register_view_model.dart';
import '../widgets/register_parts.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_numbers.dart';

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
        overline: AppStrings.yourSpot,
        title: AppStrings.youLlRideFrom(a.spotName ?? a.hubLabel ?? a.area.name),
        body: AppStrings.thisSpotIsAssignedToYou,
        content: RiderInfoCard(
          children: [
            RiderInfoRow(AppStrings.spot, value: a.spotName ?? ''),
            RiderInfoRow(
              AppStrings.distanceFromHub,
              value: a.spotDistanceKm == null
                  ? ''
                  : distance(a.spotDistanceKm!),
            ),
            const RiderInfoRow(AppStrings.weVeNotifiedYou, value: AppStrings.onYourPhone),
          ],
        ),
        actions: [RiderButton(AppStrings.gotIt, loading: busy, onPressed: vm.finish)],
      ),
      RegistrationStatus.approved => RiderArtPage.status(
        art: const RiderArtTile.small(
          icon: Icons.verified_outlined,
          iconColor: RiderColors.white,
        ),
        overline: AppStrings.welcomeAboard,
        title: AppStrings.youReApproved(a.name.trim().split(' ').first),
        body: AppStrings.yourAccountIsReadySignIn,
        content: RiderInfoCard(
          children: [
            RiderInfoRow(AppStrings.hub, value: a.hubLabel ?? a.area.name),
            RiderInfoRow(AppStrings.firstShift, value: a.firstShift ?? ''),
            const RiderInfoRow(AppStrings.scooter, value: AppStrings.assignedAtTheHub),
          ],
        ),
        actions: [RiderButton(AppStrings.signIn, onPressed: vm.showSpot)],
      ),
      RegistrationStatus.needsRetake => _issuesPage(
        icon: Icons.flip_camera_ios_outlined,
        overline: AppStrings.actionNeeded,
        title: a.issues.length == 1
            ? AppStrings.oneDocumentNeedsARetake
            : AppStrings.documentsNeedARetake(a.issues.length),
        // Figma draws one document; with more, the rest wait on the documents
        // screen, where the first retake leads.
        body: a.issues.length == 1
            ? AppStrings.letSGetAClearerPhoto(a.issues.first.$1.name)
            : '',
        issueLabel: (_) => AppStrings.retake,
        action: AppStrings.retake2(a.issues.first.$1.name),
        onAction: () => vm.fix(document: a.issues.first.$1),
        busy: busy,
      ),
      RegistrationStatus.failed => _issuesPage(
        icon: Icons.warning_amber_rounded,
        overline: AppStrings.almostDone,
        title:
            AppStrings.letSFix(a.issues.length, a.issues.length == 1 ? AppStrings.detail : AppStrings.details2),
        body: AppStrings.uploadThemAgainAndWeLl(_failedSummary(a)),
        issueLabel: (issue) => switch (issue) {
          DocumentIssue.nameMismatch => AppStrings.nameNeedsMatching,
          DocumentIssue.expired => AppStrings.expired,
          DocumentIssue.retake => AppStrings.photoNeedsARetake,
        },
        action: AppStrings.uploadDocumentsByHand,
        onAction: () => vm.fix(),
        busy: busy,
      ),
      RegistrationStatus.expired => _issuesPage(
        icon: Icons.schedule_rounded,
        overline: AppStrings.documentExpired,
        title: AppStrings.timeToRenewYour(_expired(a).name),
        body:
            AppStrings.addYourRenewedToKeepTaking(_expired(a).renewName ?? _expired(a).name),
        issueLabel: (_) => AppStrings.expired,
        action: AppStrings.update(_expired(a).name),
        onAction: () => vm.fix(),
        busy: busy,
      ),
      _ => RiderArtPage.status(
        art: RiderArtTile.small(
          icon: Icons.hourglass_empty_rounded,
          tone: RiderColors.warning,
          innerColor: RiderColors.warning.withValues(alpha: AppOpacity.o0_16),
          iconColor: RiderColors.white,
        ),
        overline: AppStrings.step3Of3,
        title: AppStrings.documentsUnderReview,
        body:
            AppStrings.ourTeamWillCheckThemUsually(phoneNumber(a.phone)),
        content: RiderInfoCard(
          children: [
            RiderInfoRow(
              AppStrings.submitted,
              value: a.submittedAt == null
                  ? ''
                  : _when(a.submittedAt!, now ?? DateTime.now()),
            ),
            RiderInfoRow(AppStrings.hub, value: a.hubLabel ?? a.area.name),
            const RiderInfoRow(
              AppStrings.status,
              labelColor: RiderColors.ink,
              trailing: RiderStatusPill.chip(
                AppStrings.underReview,
                color: RiderColors.warning,
                textColor: RiderColors.warningText,
                tint: RiderColors.warningBanner,
              ),
            ),
          ],
        ),
        // Looks for the review result now; it also moves on by itself when
        // the result arrives (09, 11–13).
        actions: [RiderButton(AppStrings.done, onPressed: vm.checkReview)],
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
                  ? RiderStatusPill.added
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
    final photoText = photos == 1 ? AppStrings.onePhoto : AppStrings.photos(photos);
    if (name && photos > 0) {
      return AppStrings.yourNameAndNeedAQuick(photoText);
    }
    if (name) return AppStrings.yourNameNeedsAQuickUpdate;
    return AppStrings.aQuickUpdate(photoText[0].toUpperCase(), photoText.substring(1), photos == 1 ? AppStrings.needs : AppStrings.need);
  }

  /// "Today, 2:14 PM", "Yesterday, 9:05 AM" or "3 Nov, 2:14 PM".
  static String _when(DateTime t, DateTime now) {
    final time = clockTime(t);
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return AppStrings.today(time);
    if (diff == 1) return AppStrings.yesterday(time);
    return AppStrings.dateWithTime(t.day, AppStrings.shortMonths[t.month - 1], time);
  }
}
