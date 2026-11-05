import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../domain/entities/online_status.dart';
import '../../domain/usecases/spot_usecases.dart';
import '../providers/online_providers.dart';
import '../viewmodels/go_online_view_model.dart';
import '../widgets/demo_online_controls.dart';
import '../widgets/spot_map.dart';

/// Shift 19–24: on the way to the spot, one screen by [SpotStage]. Arriving
/// and confirming lead to the main map by themselves.
class GoOnlinePage extends ConsumerWidget {
  const GoOnlinePage({super.key, required this.shift});

  final Shift shift;

  /// Where the design draws the spot's dot.
  static const _spotY = 250.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goOnlineViewModelProvider);
    final vm = ref.read(goOnlineViewModelProvider.notifier);
    final spot = shift.spot;
    final position = state.position;
    final meters = position == null ? null : SpotRules.metersBetween(position, spot.point);
    final away = meters == null ? '' : distance(meters / 1000);
    final step = state.step;

    Widget map(double height, {required String label, required double labelLeft, required double px}) => SpotMap(
      spot: spot,
      height: height,
      spotY: _spotY,
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
            mapBuilder: (h) => map(h, label: 'You', labelLeft: 37, px: 64),
            sheet: [
              _Heading(
                pill: RiderStatusPill('Moving to ${spot.name}'),
                title: 'Orders are waiting at ${spot.name}',
                body: 'Your ride there is paid time, and orders reach you as soon as you arrive.',
              ),
              RiderStatsCard([
                (away, 'Distance'),
                ('${nudge.rideMinutes} min', 'Ride time'),
                (minutesSeconds(at == null ? 0 : now.difference(at).inSeconds), 'Paid time'),
              ]),
              RiderButton('Navigate to spot', onPressed: vm.navigate),
            ],
          );
        // Shift 38: in kilometres, as the frame has it.
        case SpotStage.heading:
          final left = step?.turnsLeft ?? false;
          final km = meters == null ? '' : kilometres(meters);
          return RiderMapLayout.underSheet(
            mapBuilder: (h) => map(h, label: km, labelLeft: 33, px: 128),
            overlays: [
              if (step != null && step.instruction.isNotEmpty)
                RiderMapCard(leading: RiderTurnTile(left: left), title: step.instruction, subtitle: step.street),
            ],
            sheet: [
              _Heading(
                pill: const RiderStatusPill.offline(label: 'Paid ride'),
                title: 'Heading to ${spot.name}',
                body: 'Orders are waiting there. Your ride is paid time, and orders reach you as soon as you arrive.',
              ),
              RiderButton(
                turnButtonLabel(step?.maneuver, km),
                leading: RiderTurnRightIcon(left: left, stroke: 2.5),
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
          mapBuilder: (h) => map(h, label: 'You', labelLeft: 37, px: 64),
          sheet: [
            _Heading(
              pill: const RiderStatusPill('Spot assigned'),
              title: 'Head to ${spot.name}',
              body: 'Wait there. Orders near this spot are sent to you automatically.',
            ),
            RiderStatsCard([
              (away, 'Distance'),
              (meters == null ? '' : '${SpotRules.rideMinutes(meters)} min', 'Ride time'),
            ]),
            RiderItemsToggle(
              title: 'Items on scooter',
              trailing: plural(count, 'item', 'items'),
              open: state.itemsOpen,
              items: [for (final item in items) (item.name, '× ${item.quantity}')],
              onTap: vm.toggleItems,
            ),
            RiderButton('Navigate to spot', onPressed: vm.navigate),
          ],
        );
      case SpotStage.heading:
        final almost = meters != null && SpotRules.proximity(meters) != SpotProximity.far;
        final left = step?.turnsLeft ?? false;
        return RiderMapLayout.underSheet(
          mapBuilder: (h) => map(h, label: away, labelLeft: 33, px: 128),
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
              pill: RiderStatusPill.offline(label: almost ? 'Almost there' : 'On the way'),
              title: '${almost ? 'Almost at' : 'Heading to'} ${spot.name}',
              body: almost
                  ? '${away.isEmpty ? '' : 'You’re $away away. '}Reach your spot and orders will start coming automatically.'
                  : '${away.isEmpty ? '' : 'You’re $away away. '}Follow the route and we’ll confirm when you arrive.',
            ),
            RiderButton(
              turnButtonLabel(step?.maneuver, away),
              leading: RiderTurnRightIcon(left: left, stroke: 2.5),
              onPressed: () => openDirections(spot.point),
            ),
          ],
        );
      case SpotStage.confirm:
      case SpotStage.checking:
        final checking = state.stage == SpotStage.checking;
        return RiderMapLayout.underSheet(
          mapBuilder: (h) => map(h, label: 'You', labelLeft: 33, px: 37),
          floating: [
            if (kDemoMode && !checking)
              Positioned(
                right: 16,
                top: 340,
                child: DemoPill(
                  key: const Key('demo_too_far'),
                  label: 'Demo: Move 240 m away',
                  onTap: vm.demoMoveAway,
                ),
              ),
          ],
          sheet: [
            _Heading(
              pill: const RiderStatusPill.offline(label: 'Location not accurate'),
              title: 'Are you at ${spot.name}?',
              body:
                  'Your phone can’t pinpoint your location. If you’re at the spot, confirm it to start getting orders.',
            ),
            RiderButton(
              'Yes, I’m at the spot',
              onPressed: vm.confirm,
              loading: checking,
              loadingLabel: 'Checking your location…',
            ),
            RiderButton.ghost('Not yet, still on the way', onPressed: checking ? () {} : vm.notYet),
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
      const SizedBox(height: 8),
      Text(title, style: RiderText.h4),
      const SizedBox(height: 8),
      Text(body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
    ],
  );
}
