import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/shift.dart';
import '../providers/shift_providers.dart';
import '../viewmodels/shift_flow_view_model.dart';

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
      title: 'Your stock at ${shift.hub.name}',
      onBack: ref.read(shiftFlowViewModelProvider.notifier).home,
      headerPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      backSize: 48,
      backBordered: true,
      bottomPadding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
      bottomMargin: const EdgeInsets.only(bottom: 40),
      bottom: const [RiderButton('Waiting for the hub…', onPressed: null, dimmed: true)],
      children: [
        RiderSummaryCard(
          divided: false,
          radius: RiderRadius.field,
          rows: [
            ('Shift starts', clockTime(shift.start)),
            ('Ready in', readyIn == null ? '' : 'About $readyIn min'),
          ],
        ),
        const SizedBox(height: 12),
        RiderPanel(
          radius: RiderRadius.field,
          gap: 16,
          children: [
            RiderStepRow(title: 'Request sent', state: step(status.confirmed, false)),
            RiderStepRow(title: 'Hub accepted', state: step(accepted, status == StockRequestStatus.requested)),
            RiderStepRow(
              title: 'Packing your order',
              subtitle: status == StockRequestStatus.packing && readyIn != null ? 'Ready in about $readyIn min' : null,
              state: step(ready, status == StockRequestStatus.packing),
            ),
            RiderStepRow(title: 'Ready to collect', state: step(ready, false)),
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
    return seconds <= 60 ? 1 : (seconds / 60).ceil();
  }
}
