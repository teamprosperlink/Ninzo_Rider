import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/shift.dart';
import '../../shift/providers/shift_providers.dart';
import '../../../domain/entities/online_status.dart';
import '../../../domain/usecases/spot_usecases.dart';
import '../providers/online_providers.dart';
import '../viewmodels/go_online_view_model.dart';
import '../widgets/demo_online_controls.dart';
import '../widgets/spot_map.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';
import '../../../core/constants/app_keys.dart';

/// Shift 19–24: on the way to the spot, one screen by [SpotStage]. Arriving
/// and confirming lead to the main map by themselves.
class GoOnlinePage extends ConsumerWidget {
  const GoOnlinePage({super.key, required this.shift});

  final Shift shift;


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goOnlineViewModelProvider);
    final vm = ref.read(goOnlineViewModelProvider.notifier);
    final spot = shift.spot;
    final position = state.position;
    final meters = position == null ? null : SpotRules.metersBetween(position, spot.point);
    final away = meters == null ? '' : distance(meters / AppLimits.metersPerKm);
    final step = state.step;

    Widget map(double height, {required String label, required double labelLeft, required double px}) => SpotMap(
      spot: spot,
      height: height,
      spotY: RiderLayout.goOnlineSpotY,
      spotLabel: spot.name,
      rider: position,
      riderLabel: label,
      riderLabelLeft: labelLeft,
      riderPx: px,
    );

    final nudge = ref.watch(onlineStatusProvider.select((s) => s.value?.nudge));
    if (nudge != null && nudge.stage == NudgeStage.accepted) {
      final at = nudge.acceptedAt;
      switch (state.stage) {
        // Shift 37.
        case SpotStage.overview:
          final now = watchSecondClock(ref);
          return RiderMapLayout.underSheet(
            mapBuilder: (h) => map(h, label: AppStrings.you, labelLeft: AppSizes.s37, px: AppSizes.s64),
            sheet: [
              _Heading(
                pill: RiderStatusPill(AppStrings.movingTo(spot.name)),
                title: AppStrings.ordersAreWaitingAt(spot.name),
                body: AppStrings.yourRideThereIsPaidTime,
              ),
              RiderStatsCard([
                (away, AppStrings.distance),
                (AppStrings.min(nudge.rideMinutes), AppStrings.rideTime),
                (minutesSeconds(at == null ? 0 : now.difference(at).inSeconds), AppStrings.paidTime),
              ]),
              RiderButton(AppStrings.navigateToSpot, onPressed: vm.navigate),
            ],
          );
        // Shift 38: in kilometres, as the frame has it.
        case SpotStage.heading:
          final left = step?.turnsLeft ?? false;
          final km = meters == null ? '' : kilometres(meters);
          return RiderMapLayout.underSheet(
            mapBuilder: (h) => map(h, label: km, labelLeft: AppSizes.s33, px: AppSizes.s128),
            overlays: [
              if (step != null && step.instruction.isNotEmpty)
                RiderMapCard(leading: RiderTurnTile(left: left), title: step.instruction, subtitle: step.street),
            ],
            sheet: [
              _Heading(
                pill: const RiderStatusPill.offline(label: AppStrings.paidRide),
                title: AppStrings.headingTo(spot.name),
                body: AppStrings.ordersAreWaitingThereYourRide,
              ),
              RiderButton(
                turnButtonLabel(step?.maneuver, km),
                leading: RiderTurnRightIcon(left: left, stroke: AppSizes.s2_5),
                onPressed: () => openDirections(spot.point),
              ),
            ],
          );
        // Shift 23, 24 below, at the new spot.
        case SpotStage.confirm:
        case SpotStage.checking:
          break;
      }
    }

    switch (state.stage) {
      case SpotStage.overview:
        final items = ref.watch(scooterItemsProvider).value ?? const [];
        final count = shift.stock.items;
        return RiderMapLayout.underSheet(
          mapBuilder: (h) => map(h, label: AppStrings.you, labelLeft: AppSizes.s37, px: AppSizes.s64),
          sheet: [
            _Heading(
              pill: const RiderStatusPill(AppStrings.spotAssigned),
              title: AppStrings.headTo(spot.name),
              body: AppStrings.waitThereOrdersNearThisSpot,
            ),
            RiderStatsCard([
              (away, AppStrings.distance),
              (meters == null ? '' : AppStrings.min(SpotRules.rideMinutes(meters)), AppStrings.rideTime),
            ]),
            RiderItemsToggle(
              title: AppStrings.itemsOnScooter,
              trailing: plural(count, AppStrings.item, AppStrings.items2),
              open: state.itemsOpen,
              items: [for (final item in items) (item.name, AppStrings.timesCount(item.quantity))],
              onTap: vm.toggleItems,
            ),
            RiderButton(AppStrings.navigateToSpot, onPressed: vm.navigate),
          ],
        );
      case SpotStage.heading:
        final almost = meters != null && SpotRules.proximity(meters) != SpotProximity.far;
        final left = step?.turnsLeft ?? false;
        return RiderMapLayout.underSheet(
          mapBuilder: (h) => map(h, label: away, labelLeft: AppSizes.s33, px: AppSizes.s128),
          overlays: [
            if (step != null && step.instruction.isNotEmpty)
              RiderMapCard(
                leading: RiderTurnTile(left: left),
                title: step.instruction,
                subtitle: step.street,
              ),
          ],
          sheet: [
            _Heading(
              pill: RiderStatusPill.offline(label: almost ? AppStrings.almostThere : AppStrings.onTheWay),
              title: AppStrings.spacePair(almost ? AppStrings.almostAt : AppStrings.headingTo2, spot.name),
              body: almost
                  ? AppStrings.reachYourSpotAndOrdersWill(away.isEmpty ? '' : AppStrings.youReAway(away))
                  : AppStrings.followTheRouteAndWeLl(away.isEmpty ? '' : AppStrings.youReAway(away)),
            ),
            RiderButton(
              turnButtonLabel(step?.maneuver, away),
              leading: RiderTurnRightIcon(left: left, stroke: AppSizes.s2_5),
              onPressed: () => openDirections(spot.point),
            ),
          ],
        );
      case SpotStage.confirm:
      case SpotStage.checking:
        final checking = state.stage == SpotStage.checking;
        return RiderMapLayout.underSheet(
          mapBuilder: (h) => map(h, label: AppStrings.you, labelLeft: AppSizes.s33, px: AppSizes.s37),
          floating: [
            if (kDemoControls && !checking)
              Positioned(
                right: AppSizes.s16,
                top: AppSizes.s340,
                child: DemoPill(
                  key: const Key(AppKeys.demoTooFar),
                  label: AppStrings.demoMove240MAway,
                  onTap: vm.demoMoveAway,
                ),
              ),
          ],
          sheet: [
            _Heading(
              pill: const RiderStatusPill.offline(label: AppStrings.locationNotAccurate),
              title: AppStrings.areYouAt(spot.name),
              body:
                  AppStrings.yourPhoneCanTPinpointYour,
            ),
            RiderButton(
              AppStrings.yesIMAtTheSpot,
              onPressed: vm.confirm,
              loading: checking,
              loadingLabel: AppStrings.checkingYourLocation,
            ),
            RiderButton.ghost(AppStrings.notYetStillOnTheWay, onPressed: checking ? () {} : vm.notYet),
          ],
        );
    }
  }
}

/// Status pill, H4 title and grey body, as all the map sheets open.
class _Heading extends StatelessWidget {
  const _Heading({required this.pill, required this.title, required this.body});

  final Widget pill;
  final String title;
  final String body;

  /// Letter spacing of [body], to keep a tight line wrapping as designed.

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      pill,
      const SizedBox(height: AppSizes.s8),
      Text(title, style: RiderText.h4),
      const SizedBox(height: AppSizes.s8),
      Text(body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
    ],
  );
}
