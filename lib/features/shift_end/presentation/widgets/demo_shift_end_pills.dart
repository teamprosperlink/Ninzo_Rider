import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../online/di/online_di.dart';
import '../../../online/presentation/widgets/demo_online_controls.dart';
import '../../../stock/di/stock_di.dart';
import '../../di/shift_end_di.dart';

/// Demo mode only, not part of the design: on Home, what the next "Start
/// riding" runs into (Shift 54, 55).
class DemoStartPill extends ConsumerStatefulWidget {
  const DemoStartPill({super.key});

  @override
  ConsumerState<DemoStartPill> createState() => _DemoStartPillState();
}

class _DemoStartPillState extends ConsumerState<DemoStartPill> {
  static const _labels = ['No internet', 'Shift open on another phone', 'Normal start'];

  // Survives leaving Home.
  static var _next = 0;

  void _play() {
    final signal = ref.read(demoSignalProvider);
    final session = ref.read(demoShiftSessionProvider);
    signal?.online = _next != 0;
    session?.otherPhone = _next == 1;
    setState(() => _next = (_next + 1) % _labels.length);
  }

  @override
  Widget build(BuildContext context) => Positioned(
    right: 16,
    bottom: 120,
    child: DemoPill(key: const Key('demo_start'), label: 'Demo: ${_labels[_next]}', onTap: _play),
  );
}

/// Demo mode only: the signal returns on Shift 55.
class DemoSignalBackPill extends ConsumerWidget {
  const DemoSignalBackPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Positioned(
    right: 16,
    bottom: 120,
    child: DemoPill(
      key: const Key('demo_signal_back'),
      label: 'Demo: Signal on',
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
    right: 16,
    top: 292,
    child: DemoPill(
      key: const Key('demo_order_comes'),
      label: 'Demo: Order comes',
      onTap: () {
        final repository = ref.read(demoOnlineProvider);
        repository?.set(repository.status.copyWith(queue: repository.sampleQueue));
      },
    ),
  );
}
