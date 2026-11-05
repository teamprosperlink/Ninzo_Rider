import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/entities/problem_report.dart';
import '../../domain/usecases/handover_usecases.dart';
import '../viewmodels/handover_view_model.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../viewmodels/problem_report_view_model.dart';
import '../widgets/demo_order_controls.dart';
import 'handover_result_pages.dart';

/// An order at the gate, from "Hand over order" until it's delivered. Figma's
/// frames are states of these screens, see [HandoverStep].
class HandoverPage extends ConsumerWidget {
  const HandoverPage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(handoverViewModelProvider.select((s) => s.step));
    final page = switch (step) {
      HandoverStep.pack => _PackPage(order: order),
      HandoverStep.quantity => _CheckItemsPage(order: order),
      HandoverStep.code => const _CustomerCodePage(),
      HandoverStep.waiting => _CustomerWaitingPage(order: order),
      HandoverStep.details => CheckDetailsPage(order: order),
      HandoverStep.cash => CollectCashPage(order: order),
      HandoverStep.saved => HandoverSavedPage(order: order),
    };
    if (!kDemoMode) return page;
    return Stack(
      fit: StackFit.expand,
      children: [
        page,
        Positioned(top: MediaQuery.viewPaddingOf(context).top + 12, right: 16, child: const DemoHandoverControls()),
      ],
    );
  }
}

/// The back arrow and title of the handover's screens (Handover 01–05, 07–09).
const _headerGap16 = RiderHeader.flowPadding;
const _headerGap12 = EdgeInsets.fromLTRB(16, 0, 16, 12);

/// The fading bar under Handover 01 and 07.
const _bottomPadding = EdgeInsets.fromLTRB(16, 24, 16, 12);

/// The white bar under Handover 08 and 09.
const _whiteBar = BoxDecoration(color: RiderColors.white, boxShadow: riderShadow);
const _whiteBarPadding = EdgeInsets.fromLTRB(16, 12, 16, 24);

void _back(WidgetRef ref) {
  if (!ref.read(handoverViewModelProvider.notifier).back()) {
    ref.read(orderFlowViewModelProvider.notifier).backToGateConfirmed();
  }
}

/// Handover 01.
class _PackPage extends ConsumerWidget {
  const _PackPage({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticked = ref.watch(handoverViewModelProvider.select((s) => s.ticked));
    final vm = ref.read(handoverViewModelProvider.notifier);
    final gate = order.gate;
    final trip = order.tripMeters;
    final packed = isPacked(order, ticked);
    return RiderScaffold(
      title: 'Pack order #${order.number}',
      onBack: () => _back(ref),
      backSize: 48,
      backBordered: true,
      headerPadding: _headerGap16,
      bottomPadding: _bottomPadding,
      bottomNote: packed ? null : 'Tick all items to continue',
      bottom: [RiderButton('Packed – go', onPressed: packed ? vm.packed : null)],
      children: [
        const Align(alignment: Alignment.centerLeft, child: RiderStatusPill('90 sec starts when you move')),
        const SizedBox(height: 16),
        RiderPanel(
          gap: 16,
          children: [
            for (final (i, item) in order.items.indexed)
              RiderCheckRow(
                title: '${item.name} × ${item.quantity}',
                subtitle: 'Take from the hot box',
                checked: ticked.contains(i),
                onTap: () => vm.toggle(i),
              ),
            RiderCheckRow(
              title: 'Bag sealed',
              subtitle: 'Fold and press the seal',
              checked: ticked.contains(order.items.length),
              onTap: () => vm.toggle(order.items.length),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RiderSummaryCard(
          rows: [
            ('Deliver to', '${gate.name} – ${gate.landmark}'),
            ('Distance', trip == null ? '' : kilometres(trip)),
          ],
        ),
      ],
    );
  }
}

/// Handover 08, and 09 with a number changed.
class _CheckItemsPage extends ConsumerWidget {
  const _CheckItemsPage({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(handoverViewModelProvider);
    final vm = ref.read(handoverViewModelProvider.notifier);
    final quantities = state.quantitiesOf(order);
    final note = partialNoteOf(order, quantities);
    return RiderScaffold(
      title: 'Check the items',
      onBack: () => _back(ref),
      backSize: 48,
      backBordered: true,
      headerPadding: _headerGap12,
      bottomToEdge: true,
      bottomDecoration: _whiteBar,
      bottomPadding: _whiteBarPadding,
      bottom: [
        RiderButton(
          'Continue to code',
          onPressed: handedOverItems(order, quantities).isEmpty ? null : vm.continueFromQuantity,
          loading: state.busy,
        ),
        if (note != null) RiderButton.ghost('Reset quantities', onPressed: vm.resetQuantities),
      ],
      children: [
        if (note == null)
          Text(
            'Hand over what the customer ordered. Change a number only if something is missing.',
            style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: RiderColors.tipFill, borderRadius: BorderRadius.circular(RiderRadius.m)),
            child: Text(note, style: RiderText.labelMedium.copyWith(color: RiderColors.warningText)),
          ),
        const SizedBox(height: 12),
        RiderPanel(
          gap: 16,
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
                        const SizedBox(height: 2),
                        Text('Ordered × ${item.quantity}', style: RiderText.caption),
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
class _CustomerCodePage extends ConsumerWidget {
  const _CustomerCodePage();

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
                      title: 'At the gate',
                      onBack: () => _back(ref),
                      backSize: 48,
                      backBordered: true,
                      padding: _headerGap16,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const RiderTitleBlock(
                              title: 'Ask for the customer’s code',
                              subtitle: 'Enter the 4-digit code the customer shows you to hand over the order.',
                            ),
                            const SizedBox(height: 16),
                            RiderCodeBoxes.large(
                              length: HandoverRules.codeLength,
                              value: state.code,
                              error: state.wrongCode,
                              dimmed: state.busy,
                            ),
                            if (state.wrongCode) ...[
                              const SizedBox(height: 16),
                              const RiderInlineMessage(
                                'Almost there! Check the 4-digit code with the customer and enter it again.',
                              ),
                              const SizedBox(height: 16),
                              _CodeLink('Code not working? Check order details', onTap: vm.checkDetails),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: RiderButton(
                        'Confirm delivery',
                        loading: state.busy,
                        loadingLabel: 'Confirming…',
                        onPressed: state.code.length == HandoverRules.codeLength ? vm.confirmCode : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            RiderKeypad(onDigit: vm.digit, onBackspace: vm.backspace, enabled: !state.busy, keyWidth: 100),
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
class _CustomerWaitingPage extends ConsumerWidget {
  const _CustomerWaitingPage({required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchOrderTime(ref);
    final since = ref.watch(handoverViewModelProvider.select((s) => s.waitingSince)) ?? now;
    final seconds = now.difference(since).inSeconds;
    return RiderScaffold(
      title: 'At the gate',
      onBack: () => _back(ref),
      backSize: 48,
      backBordered: true,
      headerPadding: _headerGap16,
      bottomPadding: _bottomPadding,
      bottom: [
        RiderButton(
          'Call customer (masked)',
          onPressed: () {
            final phone = order.customerPhone;
            if (phone != null) callPhone(phone);
          },
        ),
        RiderButton.ghost(
          'Can’t reach customer',
          onPressed: () =>
              ref.read(problemReportViewModelProvider.notifier).open(kind: ProblemKind.customerAbsent),
        ),
      ],
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: RiderStatusPill('Waiting for customer', color: RiderColors.grey, textColor: RiderColors.ink),
        ),
        const SizedBox(height: 8),
        Text('Hang on a moment', style: RiderText.h4),
        const SizedBox(height: 8),
        Text(
          'We’ve told the customer you’re at ${order.gate.name}. You can wait a little longer.',
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: 16),
        RiderPanel(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Waiting for', style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
                ),
                Text(clock(seconds < 0 ? 0 : seconds), style: RiderText.metricLarge),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
