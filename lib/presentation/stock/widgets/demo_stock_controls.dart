import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../injection_container.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_keys.dart';

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
      left: AppSizes.s0,
      right: AppSizes.s0,
      bottom: AppSizes.s172 + MediaQuery.viewPaddingOf(context).bottom - AppSizes.s16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Pill(
            key: const Key(AppKeys.demoSignal),
            label: AppStrings.demoSignal(state.online ? AppStrings.textOn : AppStrings.off),
            onTap: signal == null ? null : () => signal.online = !signal.online,
          ),
          const SizedBox(width: AppSizes.s8),
          _Pill(
            key: const Key(AppKeys.demoCamera),
            label: AppStrings.demoCamera(state.cameraOn ? AppStrings.textOn : AppStrings.off),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.s12, vertical: AppSizes.s8),
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
