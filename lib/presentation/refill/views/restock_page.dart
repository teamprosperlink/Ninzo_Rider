import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../shift/providers/shift_providers.dart';
import '../../../domain/entities/restock.dart';
import '../viewmodels/refill_view_model.dart';
import '../widgets/demo_refill_controls.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

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
          // A fresh request to the hub, then the hub trip (Refill 03).
          RiderButton(AppStrings.askForARestock, onPressed: vm.goRefill, loading: busy),
          RiderButton.ghost(AppStrings.backToWaiting, onPressed: vm.dismissRestock),
        ],
        padding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s48, AppSizes.s16, AppSizes.s16),
        children: [
          Center(
            child: Container(
              width: AppSizes.s72,
              height: AppSizes.s72,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: RiderColors.tipFill, shape: BoxShape.circle),
              child: const Text(AppStrings.stopwatchEmoji, style: RiderText.timerGlyph),
            ),
          ),
          const SizedBox(height: AppSizes.s12),
          Text(AppStrings.thatSuggestionRanOut, textAlign: TextAlign.center, style: RiderText.h4),
          const SizedBox(height: AppSizes.s12),
          Text(
            AppStrings.weLlDraftANewOne,
            textAlign: TextAlign.center,
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
          ),
        ],
      );
    } else if (request.stage == RestockStage.suggested && editing != null) {
      page = _Screen(
        title: AppStrings.editQuantity,
        onBack: vm.cancelEdit,
        bottom: [
          RiderButton(AppStrings.confirmRestock, onPressed: vm.confirmRestock, loading: busy),
          RiderButton.ghost(AppStrings.cancel, onPressed: vm.cancelEdit),
        ],
        children: [
          RiderPanel(
            radius: RiderRadius.field,
            gap: AppSizes.s16,
            children: [
              for (final (i, line) in editing.indexed)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.name, style: RiderText.labelLarge),
                          const SizedBox(height: AppSizes.s2),
                          Text(AppStrings.from(hub), style: RiderText.caption),
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
          const SizedBox(height: AppSizes.s12),
          Text(AppStrings.yourScooterHoldsUpToItems(RestockRules.scooterHolds), style: RiderText.caption),
        ],
      );
    } else if (request.stage == RestockStage.suggested) {
      page = _Screen(
        title: AppStrings.restockSuggestion,
        onBack: vm.dismissRestock,
        bottom: [
          RiderButton(AppStrings.confirmRestock, onPressed: vm.confirmRestock, loading: busy),
          RiderButton.ghost(AppStrings.editQuantity, onPressed: vm.editQuantity),
          RiderButton.ghost(AppStrings.notNow, onPressed: vm.dismissRestock),
        ],
        children: [
          RiderPanel(
            radius: RiderRadius.field,
            children: [
              RiderLeftOverline(
                AppStrings.from2(hub.toUpperCase()),
                style: RiderText.overlineSpaced2.copyWith(color: RiderColors.grey),
              ),
              Text(RestockRules.headline(request.lines), style: RiderText.displayXl),
              // The rider API sends neither time: no empty rows then.
              if (request.readyInMinutes != null) _row(AppStrings.readyIn, AppStrings.min(request.readyInMinutes)),
              if (request.rideMinutes != null) _row(AppStrings.rideTime, AppStrings.min(request.rideMinutes)),
            ],
          ),
          const SizedBox(height: AppSizes.s12),
          Text(AppStrings.weWorkedThisOutFromYour, style: RiderText.caption),
        ],
      );
    } else if (request.stage == RestockStage.hubShort && request.shortage != null) {
      final short = request.shortage!;
      page = _Screen(
        title: AppStrings.restockAt(hub),
        onBack: vm.backToMap,
        bottom: [
          RiderButton(AppStrings.takeFrom(short.canGive, hub), onPressed: vm.takeWhatHubHas, loading: busy),
          RiderButton.ghost(AppStrings.tryLabel(short.otherHubName), onPressed: vm.tryOtherHub),
        ],
        children: [
          RiderWarningStrip(
            AppStrings.hasOfRightNow(hub, short.canGive, short.asked, RestockRules.pluralName(short.itemName, short.asked)),
            color: RiderColors.tipFill,
          ),
          const SizedBox(height: AppSizes.s12),
          RiderSummaryCard(
            divided: false,
            radius: RiderRadius.field,
            rows: [
              (AppStrings.youAskedFor, '${short.asked}'),
              (AppStrings.hubCanGive, '${short.canGive}'),
              (AppStrings.bracketPair(short.otherHubName, distance(short.otherHubKm)), AppStrings.has(short.otherHubHas)),
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
        title: AppStrings.restockAt(hub),
        onBack: vm.backToMap,
        bottom: [
          RiderButton(AppStrings.headTo(hub), onPressed: vm.headToHub, loading: busy),
          RiderButton.ghost(AppStrings.cancelRestock, onPressed: vm.dismissRestock),
        ],
        children: [
          RiderSummaryCard(
            divided: false,
            radius: RiderRadius.field,
            rows: [
              (AppStrings.yourQueueSlot, request.queueSlot == null ? '' : ordinal(request.queueSlot!)),
              (AppStrings.arriveBy, arrive == null ? '' : lowerClockTime(arrive)),
            ],
          ),
          const SizedBox(height: AppSizes.s12),
          RiderPanel(
            radius: RiderRadius.field,
            gap: AppSizes.s16,
            children: [
              // Request sent shows done as soon as it's confirmed.
              RiderStepRow(title: AppStrings.requestSent, state: RiderStepState.done),
              RiderStepRow(
                title: AppStrings.hubAccepted,
                state: request.packing == HubPacking.sent ? RiderStepState.current : RiderStepState.done,
              ),
              RiderStepRow(
                title: AppStrings.packingYourOrder,
                subtitle: request.packing == HubPacking.packing && minutes != null
                    ? AppStrings.readyInAboutMin(minutes)
                    : null,
                state: step(HubPacking.packing),
              ),
              RiderStepRow(
                title: AppStrings.readyToCollect,
                state: request.packing == HubPacking.ready ? RiderStepState.done : RiderStepState.todo,
              ),
            ],
          ),
        ],
      );
    }
    if (!kDemoControls) return page;
    return Stack(children: [page, DemoRestockPill(request: request)]);
  }

  static int? _minutesUntil(DateTime? at, DateTime now) {
    if (at == null) return null;
    final seconds = at.difference(now).inSeconds;
    return seconds <= AppLimits.secondsPerMinute ? 1 : (seconds / AppLimits.secondsPerMinute).ceil();
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
    this.padding = const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s16),
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
    headerPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s12),
    backSize: AppSizes.s48,
    backBordered: true,
    bodyPadding: padding,
    bottomToEdge: true,
    bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
    bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s12, AppSizes.s16, AppSizes.s24),
    bottom: bottom,
    children: children,
  );
}
