import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../injection_container.dart';
import '../../online/widgets/demo_online_controls.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_keys.dart';

/// Demo mode only, not part of the design: on Home, what the next "Start
/// riding" runs into (Shift 54, 55).
class DemoStartPill extends ConsumerStatefulWidget {
  const DemoStartPill({super.key});

  @override
  ConsumerState<DemoStartPill> createState() => _DemoStartPillState();
}

class _DemoStartPillState extends ConsumerState<DemoStartPill> {

  // Survives leaving Home.
  static var _next = 0;

  void _play() {
    final signal = ref.read(demoSignalProvider);
    final session = ref.read(demoShiftSessionProvider);
    signal?.online = _next != 0;
    session?.otherPhone = _next == 1;
    setState(() => _next = (_next + 1) % AppStrings.demoShiftEndLabels.length);
  }

  @override
  Widget build(BuildContext context) => Positioned(
    right: AppSizes.s16,
    bottom: AppSizes.s120,
    child: DemoPill(key: const Key(AppKeys.demoStart), label: AppStrings.demo(AppStrings.demoShiftEndLabels[_next]), onTap: _play),
  );
}

/// Demo mode only: the signal returns on Shift 55.
class DemoSignalBackPill extends ConsumerWidget {
  const DemoSignalBackPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Positioned(
    right: AppSizes.s16,
    bottom: AppSizes.s120,
    child: DemoPill(
      key: const Key(AppKeys.demoSignalBack),
      label: AppStrings.demoSignalOn,
      onTap: () => ref.read(demoSignalProvider)?.online = true,
    ),
  );
}

/// Demo mode only: an order is assigned while Shift 48 is up, so "End shift"
/// leads to Shift 47.
class DemoOrderComesPill extends ConsumerWidget {
  const DemoOrderComesPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Positioned(
    right: AppSizes.s16,
    top: AppSizes.s292,
    child: DemoPill(
      key: const Key(AppKeys.demoOrderComes),
      label: AppStrings.demoOrderComes,
      onTap: () {
        final repository = ref.read(demoOnlineProvider);
        repository?.set(repository.status.copyWith(queue: repository.sampleQueue));
      },
    ),
  );
}
