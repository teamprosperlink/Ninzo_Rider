import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../domain/entities/restock.dart';
import '../viewmodels/refill_view_model.dart';
import '../widgets/demo_refill_controls.dart';

/// Restock 01–05, one screen by [RestockStage] and whether the rider is
/// editing the quantities.
class RestockPage extends ConsumerWidget {
  const RestockPage({super.key, required this.request});

  final RestockRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    final vm = ref.read(refillViewModelProvider.notifier);
    final state = ref.watch(refillViewModelProvider);
    final editing = state.editing;
    final busy = state.busy;
    final hub = request.hubName;
    final Widget page;
    if (RestockRules.isExpired(request, now)) {
      page = _Screen(
        showBack: false,
        bottom: [
          // TODO(design): the flow map has no arrow from "Ask for a restock".
          RiderButton('Ask for a restock', onPressed: () {}),
          RiderButton.ghost('Back to waiting', onPressed: vm.dismissRestock),
        ],
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: RiderColors.tipFill, shape: BoxShape.circle),
              child: const Text('⏱', style: TextStyle(fontSize: 20, height: 26 / 20)),
            ),
          ),
          const SizedBox(height: 12),
          Text('That suggestion ran out', textAlign: TextAlign.center, style: RiderText.h4),
          const SizedBox(height: 12),
          Text(
            'We’ll draft a new one if you need it. Or ask for your own.',
            textAlign: TextAlign.center,
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
          ),
        ],
      );
    } else if (request.stage == RestockStage.suggested && editing != null) {
      page = _Screen(
        title: 'Edit quantity',
        onBack: vm.cancelEdit,
        bottom: [
          RiderButton('Confirm restock', onPressed: vm.confirmRestock, loading: busy),
          RiderButton.ghost('Cancel', onPressed: vm.cancelEdit),
        ],
        children: [
          RiderPanel(
            radius: RiderRadius.field,
            gap: 16,
            children: [
              for (final (i, line) in editing.indexed)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.name, style: RiderText.labelLarge),
                          const SizedBox(height: 2),
                          Text('From $hub', style: RiderText.caption),
                        ],
                      ),
                    ),
                    RiderRoundStepper(
                      value: line.quantity,
                      onMinus: () => vm.changeQuantity(i, -1),
                      onPlus: () => vm.changeQuantity(i, 1),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Your scooter holds up to ${RestockRules.scooterHolds} items.', style: RiderText.caption),
        ],
      );
    } else if (request.stage == RestockStage.suggested) {
      page = _Screen(
        title: 'Restock suggestion',
        onBack: vm.dismissRestock,
        bottom: [
          RiderButton('Confirm restock', onPressed: vm.confirmRestock, loading: busy),
          RiderButton.ghost('Edit quantity', onPressed: vm.editQuantity),
          RiderButton.ghost('Not now', onPressed: vm.dismissRestock),
        ],
        children: [
          RiderPanel(
            radius: RiderRadius.field,
            children: [
              Text(
                'FROM ${hub.toUpperCase()}',
                style: RiderText.overline.copyWith(color: RiderColors.grey, letterSpacing: 2),
              ),
              Text(RestockRules.headline(request.lines), style: RiderText.displayXl),
              _row('Ready in', request.readyInMinutes == null ? '' : '${request.readyInMinutes} min'),
              _row('Ride time', request.rideMinutes == null ? '' : '${request.rideMinutes} min'),
            ],
          ),
          const SizedBox(height: 12),
          Text('We worked this out from your stock and the orders on the way. You can change it.', style: RiderText.caption),
        ],
      );
    } else if (request.stage == RestockStage.hubShort && request.shortage != null) {
      final short = request.shortage!;
      page = _Screen(
        title: 'Restock at $hub',
        onBack: vm.backToMap,
        bottom: [
          RiderButton('Take ${short.canGive} from $hub', onPressed: vm.takeWhatHubHas, loading: busy),
          RiderButton.ghost('Try ${short.otherHubName}', onPressed: vm.tryOtherHub),
        ],
        children: [
          RiderWarningStrip(
            '$hub has ${short.canGive} of ${short.asked} ${RestockRules.pluralName(short.itemName, short.asked)} right now.',
            color: RiderColors.tipFill,
          ),
          const SizedBox(height: 12),
          RiderSummaryCard(
            divided: false,
            radius: RiderRadius.field,
            rows: [
              ('You asked for', '${short.asked}'),
              ('Hub can give', '${short.canGive}'),
              ('${short.otherHubName} (${distance(short.otherHubKm)})', 'Has ${short.otherHubHas}'),
            ],
          ),
        ],
      );
    } else {
      RiderStepState step(HubPacking at) {
        if (request.packing.index > at.index) return RiderStepState.done;
        return request.packing == at ? RiderStepState.current : RiderStepState.todo;
      }

      final arrive = request.arriveBy;
      final minutes = _minutesUntil(request.readyAt, now);
      page = _Screen(
        title: 'Restock at $hub',
        onBack: vm.backToMap,
        bottom: [
          RiderButton('Head to $hub', onPressed: vm.headToHub, loading: busy),
          RiderButton.ghost('Cancel restock', onPressed: vm.dismissRestock),
        ],
        children: [
          RiderSummaryCard(
            divided: false,
            radius: RiderRadius.field,
            rows: [
              ('Your queue slot', request.queueSlot == null ? '' : ordinal(request.queueSlot!)),
              ('Arrive by', arrive == null ? '' : lowerClockTime(arrive)),
            ],
          ),
          const SizedBox(height: 12),
          RiderPanel(
            radius: RiderRadius.field,
            gap: 16,
            children: [
              // Request sent shows done as soon as it's confirmed.
              RiderStepRow(title: 'Request sent', state: RiderStepState.done),
              RiderStepRow(
                title: 'Hub accepted',
                state: request.packing == HubPacking.sent ? RiderStepState.current : RiderStepState.done,
              ),
              RiderStepRow(
                title: 'Packing your order',
                subtitle: request.packing == HubPacking.packing && minutes != null
                    ? 'Ready in about $minutes min'
                    : null,
                state: step(HubPacking.packing),
              ),
              RiderStepRow(
                title: 'Ready to collect',
                state: request.packing == HubPacking.ready ? RiderStepState.done : RiderStepState.todo,
              ),
            ],
          ),
        ],
      );
    }
    if (!kDemoMode) return page;
    return Stack(children: [page, DemoRestockPill(request: request)]);
  }

  static int? _minutesUntil(DateTime? at, DateTime now) {
    if (at == null) return null;
    final seconds = at.difference(now).inSeconds;
    return seconds <= 60 ? 1 : (seconds / 60).ceil();
  }

  static Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
      RiderHugText(value, style: RiderText.labelLarge),
    ],
  );
}

/// The restock screens' frame: bordered back button, white bottom bar to the
/// screen's edge.
class _Screen extends StatelessWidget {
  const _Screen({
    this.title,
    this.showBack = true,
    this.onBack,
    required this.bottom,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> bottom;
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => RiderScaffold(
    title: title,
    showBack: showBack,
    onBack: onBack,
    headerPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    backSize: 48,
    backBordered: true,
    bodyPadding: padding,
    bottomToEdge: true,
    bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
    bottomPadding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    bottom: bottom,
    children: children,
  );
}
