import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/delivery_order.dart';
import '../../../domain/entities/problem_report.dart';
import '../../../domain/usecases/handover_usecases.dart';
import '../viewmodels/handover_view_model.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../viewmodels/problem_report_view_model.dart';
import '../widgets/demo_order_controls.dart';
import '../../../routing/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

/// An order at the gate, from "Hand over order" until it's delivered. Figma's
/// frames are states of these screens, see [HandoverStep].
class HandoverPage extends ConsumerWidget {
  const HandoverPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var step = ref.watch(handoverViewModelProvider.select((s) => s.step));
    if (kRiderApi && step == HandoverStep.pack && order.status != DeliveryStatus.assigned) {
      // Packed already: straight on to the code.
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(handoverViewModelProvider.notifier).skipPacked());
      step = takesCode(order) ? HandoverStep.code : HandoverStep.cash;
    }
    final page = handoverStepPage(step, order);
    if (!kDemoControls) return page;
    return Stack(
      fit: StackFit.expand,
      children: [
        page,
        Positioned(top: MediaQuery.viewPaddingOf(context).top + AppSizes.s12, right: AppSizes.s16, child: const DemoHandoverControls()),
      ],
    );
  }
}

/// The back arrow and title of the handover's screens (Handover 01–05, 07–09).

/// The fading bar under Handover 01 and 07.

/// The white bar under Handover 08 and 09.

void _back(WidgetRef ref) {
  if (!ref.read(handoverViewModelProvider.notifier).back()) {
    ref.read(orderFlowViewModelProvider.notifier).backToGateConfirmed();
  }
}

/// Handover 01.
class PackPage extends ConsumerWidget {
  const PackPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticked = ref.watch(handoverViewModelProvider.select((s) => s.ticked));
    final vm = ref.read(handoverViewModelProvider.notifier);
    final gate = order.gate;
    final trip = order.tripMeters;
    final packed = isPacked(order, ticked);
    return RiderScaffold(
      title: AppStrings.packOrder(order.number),
      onBack: () => _back(ref),
      backSize: AppSizes.s48,
      backBordered: true,
      headerPadding: RiderHeader.flowPadding,
      bottomPadding: RiderLayout.handoverBottomPadding,
      bottomNote: packed ? null : AppStrings.tickAllItemsToContinue,
      bottom: [RiderButton(AppStrings.packedGo, onPressed: packed ? vm.packed : null)],
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: RiderStatusPill(AppStrings.secStartsWhenYouMove(OrderRules.window.inSeconds), tint: RiderColors.greenPillOnScreen),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderPanel(
          gap: AppSizes.s16,
          children: [
            for (final (i, item) in order.items.indexed)
              RiderCheckRow(
                title: AppStrings.timesPair(item.name, item.quantity),
                subtitle: AppStrings.takeFromTheHotBox,
                checked: ticked.contains(i),
                onTap: () => vm.toggle(i),
              ),
            RiderCheckRow(
              title: AppStrings.bagSealed,
              subtitle: AppStrings.foldAndPressTheSeal,
              checked: ticked.contains(order.items.length),
              onTap: () => vm.toggle(order.items.length),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.s16),
        RiderSummaryCard(
          rows: [
            (AppStrings.deliverTo, AppStrings.dashPair(gate.name, gate.landmark)),
            (AppStrings.distance, trip == null ? '' : kilometres(trip)),
          ],
        ),
      ],
    );
  }
}

/// Handover 08, and 09 with a number changed.
class CheckItemsPage extends ConsumerWidget {
  const CheckItemsPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(handoverViewModelProvider);
    final vm = ref.read(handoverViewModelProvider.notifier);
    final quantities = state.quantitiesOf(order);
    final note = partialNoteOf(order, quantities);
    return RiderScaffold(
      title: AppStrings.checkTheItems,
      onBack: () => _back(ref),
      backSize: AppSizes.s48,
      backBordered: true,
      headerPadding: RiderLayout.handoverHeaderGap12,
      bottomToEdge: true,
      bottomDecoration: RiderLayout.handoverWhiteBar,
      bottomPadding: RiderLayout.handoverWhiteBarPadding,
      bottom: [
        RiderButton(
          AppStrings.continueToCode,
          onPressed: handedOverItems(order, quantities).isEmpty ? null : vm.continueFromQuantity,
          loading: state.busy,
        ),
        if (note != null) RiderButton.ghost(AppStrings.resetQuantities, onPressed: vm.resetQuantities),
      ],
      children: [
        if (note == null)
          Text(
            AppStrings.handOverWhatTheCustomerOrdered,
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16, vertical: AppSizes.s12),
            decoration: BoxDecoration(color: RiderColors.tipFill, borderRadius: BorderRadius.circular(RiderRadius.m)),
            child: Text(note, style: RiderText.labelMedium.copyWith(color: RiderColors.warningText)),
          ),
        const SizedBox(height: AppSizes.s12),
        RiderPanel(
          gap: AppSizes.s16,
          radius: RiderRadius.field,
          children: [
            for (final (i, item) in order.items.indexed)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: RiderText.labelLarge),
                        const SizedBox(height: AppSizes.s2),
                        Text(AppStrings.ordered(item.quantity), style: RiderText.caption),
                      ],
                    ),
                  ),
                  RiderRoundStepper(
                    value: quantities[i],
                    onMinus: () => vm.changeQuantity(i, -1),
                    onPlus: () => vm.changeQuantity(i, 1),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Handover 02 empty, 03 typing, 04 wrong code, 05 confirming. For UPI orders
/// only.
class CustomerCodePage extends ConsumerWidget {
  const CustomerCodePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(handoverViewModelProvider);
    final vm = ref.read(handoverViewModelProvider.notifier);
    return AnnotatedRegion(
      value: riderStatusBarDark,
      child: Scaffold(
        backgroundColor: RiderColors.screen,
        body: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RiderHeader(
                      title: AppStrings.atTheGate,
                      onBack: () => _back(ref),
                      backSize: AppSizes.s48,
                      backBordered: true,
                      padding: RiderHeader.flowPadding,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const RiderTitleBlock(
                              title: AppStrings.askForTheCustomerSCode,
                              subtitle: AppStrings.enterThe4DigitCodeThe,
                            ),
                            const SizedBox(height: AppSizes.s16),
                            RiderCodeBoxes.large(
                              length: HandoverRules.codeLength,
                              value: state.code,
                              error: state.wrongCode,
                              dimmed: state.busy,
                            ),
                            if (state.wrongCode) ...[
                              const SizedBox(height: AppSizes.s16),
                              const RiderInlineMessage(
                                AppStrings.almostThereCheckThe4Digit,
                              ),
                              const SizedBox(height: AppSizes.s16),
                              _CodeLink(AppStrings.codeNotWorkingCheckOrderDetails, onTap: vm.checkDetails),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s8, AppSizes.s16, AppSizes.s8),
                      child: RiderButton(
                        AppStrings.confirmDelivery,
                        loading: state.busy,
                        loadingLabel: AppStrings.confirming,
                        onPressed: state.code.length == HandoverRules.codeLength ? vm.confirmCode : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            RiderKeypad(onDigit: vm.digit, onBackspace: vm.backspace, enabled: !state.busy, keyWidth: AppSizes.s100),
          ],
        ),
      ),
    );
  }
}

class _CodeLink extends StatelessWidget {
  const _CodeLink(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(label, style: RiderText.bodyMedium.copyWith(color: RiderColors.brand)),
    ),
  );
}

/// Handover 07.
class CustomerWaitingPage extends ConsumerWidget {
  const CustomerWaitingPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchOrderTime(ref);
    final since = ref.watch(handoverViewModelProvider.select((s) => s.waitingSince)) ?? now;
    final seconds = now.difference(since).inSeconds;
    return RiderScaffold(
      title: AppStrings.atTheGate,
      onBack: () => _back(ref),
      backSize: AppSizes.s48,
      backBordered: true,
      headerPadding: RiderHeader.flowPadding,
      bottomPadding: RiderLayout.handoverBottomPadding,
      bottom: [
        RiderButton(
          AppStrings.callCustomerMasked,
          onPressed: () {
            final phone = order.customerPhone;
            if (phone != null) callPhone(phone);
          },
        ),
        RiderButton.ghost(
          AppStrings.canTReachCustomer,
          onPressed: () =>
              ref.read(problemReportViewModelProvider.notifier).open(kind: ProblemKind.customerAbsent),
        ),
      ],
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: RiderStatusPill(AppStrings.waitingForCustomer, color: RiderColors.grey, textColor: RiderColors.ink),
        ),
        const SizedBox(height: AppSizes.s8),
        Text(AppStrings.hangOnAMoment, style: RiderText.h4),
        const SizedBox(height: AppSizes.s8),
        Text(
          AppStrings.weVeToldTheCustomerYou(order.gate.name),
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderPanel(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(AppStrings.waitingFor, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
                ),
                RiderHugText(clock(seconds < 0 ? 0 : seconds), style: RiderText.metricLarge),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
