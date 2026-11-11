import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/constants/demo_data.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/restock.dart';
import '../../shift/viewmodels/shift_flow_view_model.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/shift_end.dart';
import '../../../domain/entities/online_status.dart';
import '../../../domain/usecases/online_usecases.dart';
import '../viewmodels/online_map_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_numbers.dart';
import '../../../core/constants/app_keys.dart';

/// Demo mode only, not part of the design: a small amber pill that plays the
/// backend, one state of the main map after another.
class DemoOnlineControls extends ConsumerStatefulWidget {
  const DemoOnlineControls({super.key});

  @override
  ConsumerState<DemoOnlineControls> createState() => _DemoOnlineControlsState();
}

/// What the pill plays next.
enum _Step {
  quiet(AppStrings.quietSpell),
  order(AppStrings.orderAssigned),
  lowStock(AppStrings.lowStock),
  oneLeft(AppStrings.text1ItemLeft),
  restock(AppStrings.restockSuggestion),
  nudge(AppStrings.relocationNudge),
  covered(AppStrings.nudgeCovered),
  away(AppStrings.awayFromSpot),
  battery(AppStrings.batteryLow),
  ending(AppStrings.shiftEnding),
  connectionLost(AppStrings.connectionLost),
  locationOff(AppStrings.locationOff2),
  phoneTime(AppStrings.phoneTimeWrong),
  shiftLimit(AppStrings.shiftLimit),
  earnings(AppStrings.earnings),
  sync(AppStrings.syncStatus),
  profile(AppStrings.profile),
  waiting(AppStrings.waiting2);

  const _Step(this.label);

  final String label;
}

class _DemoOnlineControlsState extends ConsumerState<DemoOnlineControls> {
  // Survives leaving the map (Add time, View stock).
  static var _next = _Step.quiet;

  void _play() {
    final repository = ref.read(demoOnlineProvider);
    final location = ref.read(demoRiderLocationProvider);
    if (repository == null || location == null) return;
    final step = _next;
    final now = ref.read(clockProvider)();
    final status = repository.status;
    // Every step starts from a rider waiting at the spot, so one banner shows.
    final base = OnlineStatus(
      onlineAt: status.onlineAt,
      orders: status.orders,
      earned: status.earned,
      sold: status.sold,
      stockAdded: status.stockAdded,
      itemsLeft: status.itemsLeft,
      averageDeliverySeconds: status.averageDeliverySeconds,
    );
    final map = ref.read(onlineMapViewModelProvider.notifier);
    final flow = ref.read(shiftFlowViewModelProvider.notifier);
    final demoSync = ref.read(demoSyncStatusProvider);
    final demoHealth = ref.read(demoDeviceHealthProvider);
    ref.read(demoSignalProvider)?.online = step != _Step.connectionLost && step != _Step.sync;
    demoSync?.sample = switch (step) {
      _Step.connectionLost => const SyncSnapshot(deliveries: 1),
      _Step.sync => SyncSnapshot(
        deliveries: 1,
        lastSync: DateTime(now.year, now.month, now.day, DemoData.lastSyncHour, DemoData.lastSyncMinute),
        events: [
          for (final (label, hour, minute) in DemoData.syncEvents)
            SyncEvent(label: label, at: DateTime(now.year, now.month, now.day, hour, minute)),
        ],
      ),
      _ => null,
    };
    final loaded = DemoData.stockPortions + status.stockAdded;
    location.moveTo(step == _Step.away ? DemoData.riderAwayMeters : DemoData.riderAtSpotMeters);
    repository.set(switch (step) {
      _Step.quiet => base.copyWith(quiet: true),
      _Step.order => base.copyWith(queue: repository.sampleQueue),
      _Step.lowStock => base.copyWith(sold: loaded - AppLimits.demoLowStockLeft > status.sold ? loaded - AppLimits.demoLowStockLeft : status.sold),
      _Step.oneLeft => base.copyWith(
        sold: loaded - 1,
        orders: DemoData.refillOrders,
        earned: DemoData.refillEarned,
        itemsLeft: [for (final (name, left) in DemoData.itemsLeftSample) ItemLeft(name: name, left: left)],
      ),
      _Step.restock => base.copyWith(
        restock: () => RestockRequest(
          stage: RestockStage.suggested,
          hubName: DemoData.restockHub,
          readyInMinutes: DemoData.restockReadyIn,
          rideMinutes: DemoData.restockRide,
          lines: [
            for (final (id, name, quantity) in DemoData.restockLines)
              RestockLine(itemId: id, name: name, quantity: quantity),
          ],
        ),
      ),
      _Step.nudge => base.copyWith(nudge: () => DemoData.sampleNudge),
      _Step.covered => base.copyWith(nudge: () => DemoData.sampleNudge.covered),
      _Step.away ||
      _Step.waiting ||
      _Step.connectionLost ||
      _Step.locationOff ||
      _Step.phoneTime ||
      _Step.profile ||
      _Step.sync => base,
      _Step.shiftLimit => base.copyWith(
        onlineAt: now.subtract(DemoData.chosenShift),
        chosenLength: () => DemoData.chosenShift,
        shiftEnd: () => now.subtract(AppDurations.seconds1),
      ),
      _Step.earnings => base.copyWith(
        orders: DemoData.earningsOrders,
        earned: DemoData.refillEarned,
        earnings: () => const EarningsBreakdown(
          orderPay: DemoData.earningsOrderPay,
          incentives: DemoData.earningsIncentives,
          repositionMinutes: DemoData.earningsRepositionMinutes,
          repositionPay: DemoData.earningsRepositionPay,
        ),
      ),
      _Step.battery => base.copyWith(batteryPercent: () => DemoData.lowBattery),
      _Step.ending => base.copyWith(shiftEnd: () => now.add(SelectOnlineAlert.endingWindow)),
    });
    _next = _Step.values[(step.index + 1) % _Step.values.length];
    // Once the status above has reached the view models.
    void soon(VoidCallback check) => Future<void>.delayed(AppDurations.milliseconds100, check);
    switch (step) {
      case _Step.locationOff:
        demoHealth?.location = false;
        soon(map.checkDevice);
      case _Step.phoneTime:
        demoHealth?.autoTime = false;
        soon(map.checkDevice);
      case _Step.shiftLimit:
        soon(map.checkShiftEnded);
      case _Step.earnings:
        flow.show(ShiftScreen.earnings);
      case _Step.sync:
        flow.show(ShiftScreen.syncStatus);
      case _Step.profile:
        flow.openProfile();
      default:
        break;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!kDemoControls) return const SizedBox.shrink();
    return DemoPill(key: const Key(AppKeys.demoOnlineNext), label: AppStrings.demo(_next.label), onTap: _play);
  }
}

/// The amber demo pill.
class DemoPill extends StatelessWidget {
  const DemoPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s12, vertical: AppSizes.s8),
      decoration: BoxDecoration(
        color: RiderColors.white,
        borderRadius: BorderRadius.circular(RiderRadius.pill),
        border: Border.all(color: RiderColors.warning),
      ),
      child: Text(label, style: RiderText.labelSmall.copyWith(color: RiderColors.warningText)),
    ),
  );
}
