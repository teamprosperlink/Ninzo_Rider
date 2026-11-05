import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/delivery_order.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../widgets/demo_order_controls.dart';
import '../widgets/gate_scanner.dart';

/// "Confirm you're at the gate": Arrival 01 scanning, 02 not confirmed, 04 with
/// the camera off.
class GatePage extends ConsumerStatefulWidget {
  const GatePage({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<GatePage> createState() => _GatePageState();
}

class _GatePageState extends ConsumerState<GatePage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Camera access may have changed in the phone's settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(orderFlowViewModelProvider.notifier).recheckCamera();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderFlowViewModelProvider);
    final vm = ref.read(orderFlowViewModelProvider.notifier);
    final order = widget.order;
    final gate = order.gate;
    final scanner = ref.watch(gateScannerProvider);
    final me = state.position;
    final meters = me == null ? null : const Distance().as(LengthUnit.Meter, me, gate.point).round();

    final List<Widget> body;
    if (state.notConfirmed) {
      body = [
        RiderWarningStrip(
          'Almost at the gate! Scan the gate QR or enter the gate code to confirm you’re here.',
          color: RiderColors.tipFill,
        ),
        const SizedBox(height: 12),
        RiderPanel(
          radius: RiderRadius.field,
          children: [
            // Flutter sets half the spacing before the first letter; Figma doesn't.
            Transform.translate(
              offset: const Offset(-1, 0),
              child: Text(
                gate.name.toUpperCase(),
                style: RiderText.overline.copyWith(color: RiderColors.grey, letterSpacing: 2),
              ),
            ),
            Text(gate.landmark, style: RiderText.h4),
            Row(
              children: [
                Expanded(
                  child: Text('Distance to gate', style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
                ),
                Text(meters == null ? '' : '$meters m', style: RiderText.labelLarge),
              ],
            ),
          ],
        ),
      ];
    } else {
      body = [
        Text(
          state.cameraOn
              ? 'Scan the QR code at ${gate.name}. Your location alone can’t confirm arrival.'
              : 'Allow camera access to scan the QR, or enter the gate code instead.',
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            RiderGateViewfinder(
              caption: state.cameraOn ? 'Point at the gate QR code' : 'Turn on camera to scan',
              preview: state.cameraOn ? scanner(context, vm.onGateCode, vm.cameraFailed) : null,
              onTap: !state.cameraOn
                  ? vm.turnOnCamera
                  : kDemoMode
                  ? vm.demoScan
                  : null,
            ),
            if (kDemoMode) const Positioned(right: 12, bottom: 12, child: DemoGateControls()),
          ],
        ),
      ];
    }

    return RiderScaffold(
      title: 'Confirm you’re at the gate',
      onBack: vm.backFromGate,
      headerPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      backSize: 48,
      backBordered: true,
      bottomToEdge: true,
      bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
      bottomPadding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      bottom: [
        if (state.notConfirmed) RiderButton('Scan QR again', onPressed: vm.scanAgain),
        // TODO(design): no frame for entering the gate code; the button is drawn but does nothing.
        RiderButton.ghost(state.notConfirmed ? 'Enter gate code' : 'Enter gate code instead', onPressed: () {}),
      ],
      children: body,
    );
  }
}
