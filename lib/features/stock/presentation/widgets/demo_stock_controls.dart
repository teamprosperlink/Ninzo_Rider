import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/rider_tokens.dart';
import '../../di/stock_di.dart';
import '../viewmodels/stock_flow_view_model.dart';

/// Demo mode only: switches for what a demo can't produce by itself, the
/// phone's signal and the camera being off. Not part of the design.
class DemoStockControls extends ConsumerWidget {
  const DemoStockControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockFlowViewModelProvider);
    final vm = ref.read(stockFlowViewModelProvider.notifier);
    final signal = ref.watch(demoSignalProvider);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 172 + MediaQuery.viewPaddingOf(context).bottom - 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Pill(
            key: const Key('demo_signal'),
            label: 'Demo: Signal ${state.online ? 'on' : 'off'}',
            onTap: signal == null ? null : () => signal.online = !signal.online,
          ),
          const SizedBox(width: 8),
          _Pill(
            key: const Key('demo_camera'),
            label: 'Demo: Camera ${state.cameraOn ? 'on' : 'off'}',
            onTap: () => vm.demoSetCameraOff(state.cameraOn),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: RiderColors.white,
        borderRadius: BorderRadius.circular(RiderRadius.pill),
        border: Border.all(color: RiderColors.warning),
      ),
      child: Text(
        label,
        style: RiderText.labelSmall.copyWith(color: RiderColors.warningText, decoration: TextDecoration.none),
      ),
    ),
  );
}
