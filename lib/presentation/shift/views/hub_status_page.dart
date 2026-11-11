import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/shift.dart';
import '../providers/shift_providers.dart';
import '../viewmodels/shift_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

/// Shift 53 "At hub · Hub is packing": where the request is, and when the
/// stock will be ready. Moves on by itself when the hub finishes.
class HubStatusPage extends ConsumerWidget {
  const HubStatusPage({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    final readyIn = _readyIn(now);
    final status = shift.stockRequest;
    RiderStepState step(bool done, bool current) =>
        done ? RiderStepState.done : (current ? RiderStepState.current : RiderStepState.todo);
    final accepted = status == StockRequestStatus.packing || status == StockRequestStatus.ready;
    final ready = status == StockRequestStatus.ready;
    return RiderScaffold(
      title: AppStrings.yourStockAt(shift.hub.name),
      onBack: ref.read(shiftFlowViewModelProvider.notifier).home,
      headerPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s12),
      backSize: AppSizes.s48,
      backBordered: true,
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s12, AppSizes.s16, AppSizes.s24),
      bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
      bottomMargin: const EdgeInsets.only(bottom: AppSizes.s40),
      bottom: const [RiderButton(AppStrings.waitingForTheHub, onPressed: null, dimmed: true)],
      children: [
        RiderSummaryCard(
          divided: false,
          radius: RiderRadius.field,
          rows: [
            (AppStrings.shiftStarts, clockTime(shift.start)),
            (AppStrings.readyIn, readyIn == null ? '' : AppStrings.aboutMin(readyIn)),
          ],
        ),
        const SizedBox(height: AppSizes.s12),
        RiderPanel(
          radius: RiderRadius.field,
          gap: AppSizes.s16,
          children: [
            RiderStepRow(title: AppStrings.requestSent, state: step(status.confirmed, false)),
            RiderStepRow(title: AppStrings.hubAccepted, state: step(accepted, status == StockRequestStatus.requested)),
            RiderStepRow(
              title: AppStrings.packingYourOrder,
              subtitle: status == StockRequestStatus.packing && readyIn != null ? AppStrings.readyInAboutMin(readyIn) : null,
              state: step(ready, status == StockRequestStatus.packing),
            ),
            RiderStepRow(title: AppStrings.readyToCollect, state: step(ready, false)),
          ],
        ),
      ],
    );
  }

  /// Whole minutes until the hub's estimate, at least 1.
  int? _readyIn(DateTime now) {
    final at = shift.stockReadyAt;
    if (at == null) return null;
    final seconds = at.difference(now).inSeconds;
    return seconds <= AppLimits.secondsPerMinute ? 1 : (seconds / AppLimits.secondsPerMinute).ceil();
  }
}
