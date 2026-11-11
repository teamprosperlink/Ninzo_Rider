import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/delivery_order.dart';
import '../viewmodels/order_flow_view_model.dart';
import '../widgets/demo_order_controls.dart';
import '../widgets/gate_scanner.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

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
          AppStrings.almostAtTheGateScanThe,
          color: RiderColors.tipFill,
        ),
        const SizedBox(height: AppSizes.s12),
        RiderPanel(
          radius: RiderRadius.field,
          children: [
            // Flutter sets half the spacing before the first letter; Figma doesn't.
            Transform.translate(
              offset: const Offset(-AppSizes.s1, AppSizes.s0),
              child: Text(
                gate.name.toUpperCase(),
                style: RiderText.overlineSpaced2.copyWith(color: RiderColors.grey),
              ),
            ),
            Text(gate.landmark, style: RiderText.h4),
            Row(
              children: [
                Expanded(
                  child: Text(AppStrings.distanceToGate, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
                ),
                Text(meters == null ? '' : AppStrings.textM(meters), style: RiderText.labelLarge),
              ],
            ),
          ],
        ),
      ];
    } else {
      body = [
        Text(
          state.cameraOn
              ? AppStrings.scanTheQrCodeAtYour(gate.name)
              : AppStrings.allowCameraAccessToScanThe,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: AppSizes.s12),
        Stack(
          children: [
            RiderGateViewfinder(
              caption: state.cameraOn ? AppStrings.pointAtTheGateQrCode : AppStrings.turnOnCameraToScan,
              preview: state.cameraOn ? scanner(context, vm.onGateCode, vm.cameraFailed) : null,
              onTap: !state.cameraOn
                  ? vm.turnOnCamera
                  : kDemoControls
                  ? vm.demoScan
                  : null,
            ),
            if (kDemoControls) const Positioned(right: AppSizes.s12, bottom: AppSizes.s12, child: DemoGateControls()),
          ],
        ),
      ];
    }

    return RiderScaffold(
      title: AppStrings.confirmYouReAtTheGate,
      onBack: vm.backFromGate,
      headerPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s0, AppSizes.s16, AppSizes.s12),
      backSize: AppSizes.s48,
      backBordered: true,
      bottomToEdge: true,
      bottomDecoration: const BoxDecoration(color: RiderColors.white, boxShadow: riderShadow),
      bottomPadding: const EdgeInsets.fromLTRB(AppSizes.s16, AppSizes.s12, AppSizes.s16, AppSizes.s24),
      bottom: [
        if (state.notConfirmed) RiderButton(AppStrings.scanQrAgain, onPressed: vm.scanAgain),
        // TODO(design): no frame for entering the gate code; the button is drawn but does nothing.
        RiderButton.ghost(state.notConfirmed ? AppStrings.enterGateCode : AppStrings.enterGateCodeInstead, onPressed: () {}),
      ],
      children: body,
    );
  }
}

