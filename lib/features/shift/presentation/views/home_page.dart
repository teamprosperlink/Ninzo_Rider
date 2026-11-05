import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/home_status.dart';
import '../../domain/entities/shift.dart';
import '../providers/shift_providers.dart';
import '../viewmodels/shift_flow_view_model.dart';

/// Home (Shift 01–09): greeting, what to do next, today's ride and the
/// action for this moment of the day.
class HomePage extends ConsumerWidget {
  const HomePage({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    ref.watch(shiftFlowViewModelProvider.select((s) => s.starting));
    final busy = ref.watch(shiftFlowViewModelProvider.select((s) => s.busy));
    final vm = ref.read(shiftFlowViewModelProvider.notifier);
    final status = vm.homeStatus(shift, now);
    final copy = _HomeCopy.of(status, shift);
    final starts = clockTime(shift.start);

    final List<Widget> actions = switch (status) {
      HomeStatus.stockNotRequested ||
      HomeStatus.offToday => [RiderButton('Ask hub to prepare', onPressed: vm.askHubToPrepare, loading: busy)],
      HomeStatus.hubPreparing => [RiderButton('Starts at $starts', onPressed: null, dimmed: true)],
      HomeStatus.stockReady || HomeStatus.startRiding => [RiderButton('Start riding', onPressed: vm.startRiding)],
      HomeStatus.starting => [RiderButton('Start riding', onPressed: () {}, loading: true, loadingLabel: 'Starting…')],
      HomeStatus.collectStock => [
        RiderButton('Go to hub', onPressed: vm.goToHub),
        RiderButton.ghost('Go online', onPressed: busy ? null : vm.goOnline, dimmed: true),
      ],
      HomeStatus.finishScanning => [RiderButton('Continue scanning', onPressed: vm.continueScanning)],
      HomeStatus.stockLoaded => [RiderButton('Go online', onPressed: vm.goOnline, loading: busy)],
    };

    return RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      // Two actions sit lower, reaching 4px into the gesture area (Shift 07).
      bottomPadding: EdgeInsets.fromLTRB(16, 8, 16, actions.length > 1 ? 0 : 12),
      bottom: [
        for (final action in actions)
          actions.length > 1 ? Transform.translate(offset: const Offset(0, 4), child: action) : action,
      ],
      children: [
        RiderHomeHeader(greeting: greeting(now), name: ref.watch(riderFirstNameProvider), onAvatarTap: vm.openProfile),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.title, style: RiderText.h4),
              const SizedBox(height: 12),
              Text(copy.body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RiderSummaryCard(
          title: 'Your ride',
          rows: [('Stock', copy.stock), ('Spot', shift.spot.name), ('Scooter', shift.scooter.plate)],
        ),
      ],
    );
  }
}

/// A rider with no shift today: Shift 02 "You're off today", with what's known.
/// There's nothing to ask the hub about until a shift arrives, when Home takes
/// over by itself; the frame's button and avatar are there, and do nothing.
class NoShiftHomePage extends ConsumerWidget {
  const NoShiftHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = watchShiftClock(ref);
    const copy = _HomeCopy.offToday;
    return RiderScaffold(
      showBack: false,
      bodyPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      bottomPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      bottom: [RiderButton('Ask hub to prepare', onPressed: () {})],
      children: [
        RiderHomeHeader(greeting: greeting(now), name: ref.watch(riderFirstNameProvider), onAvatarTap: () {}),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(copy.title, style: RiderText.h4),
              const SizedBox(height: 12),
              Text(copy.body, style: RiderText.bodyMedium.copyWith(color: RiderColors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        RiderSummaryCard(title: 'Your ride', rows: [('Stock', copy.stock), ('Spot', ''), ('Scooter', '')]),
      ],
    );
  }
}

/// Title, body and the Stock row for each Home state, as in the design.
class _HomeCopy {
  const _HomeCopy(this.title, this.body, this.stock);

  final String title;
  final String body;
  final String stock;

  static const offToday = _HomeCopy(
    'You’re off today',
    'The hub won’t pack stock for you. Changed your mind? Ask the hub to prepare.',
    'Not requested',
  );

  static _HomeCopy of(HomeStatus status, Shift shift) {
    final hub = shift.hub.name;
    final stock = shift.stock;
    final away = shift.hubDistanceKm == null ? '' : ', ${distance(shift.hubDistanceKm!)} away';
    return switch (status) {
      HomeStatus.stockNotRequested => const _HomeCopy(
        'Stock not requested',
        'The hub hasn’t been told you’re coming. Ask now and it’s usually ready in about an hour.',
        'Not requested',
      ),
      HomeStatus.offToday => offToday,
      HomeStatus.hubPreparing => _HomeCopy(
        'Hub is packing your stock',
        'Shift starts at ${clockTime(shift.start)}. We’ll tell you the moment it’s ready.',
        'Being packed',
      ),
      HomeStatus.stockReady => _HomeCopy(
        'Your stock is ready',
        '$hub has packed your order. Start riding when your shift begins.',
        'Ready at $hub',
      ),
      HomeStatus.startRiding || HomeStatus.starting => const _HomeCopy(
        'You’re offline',
        'Check in, then collect your stock at the hub. Tap Start riding to begin.',
        'Not loaded yet',
      ),
      HomeStatus.collectStock => _HomeCopy(
        'Collect your stock',
        'Head to $hub$away. Scan your items to unlock Go online.',
        shift.stockRequest == StockRequestStatus.ready ? 'Ready at $hub' : 'Being packed',
      ),
      HomeStatus.finishScanning => _HomeCopy(
        'Finish scanning your stock',
        '${stock.scanned} of ${stock.portions} portions scanned. Scan the rest to go online.',
        '${stock.scanned} of ${stock.portions} portions',
      ),
      HomeStatus.stockLoaded => _HomeCopy(
        'Stock loaded',
        '${stock.portions} portions on your scooter. You’re ready to go online.',
        '${stock.items} items · ${stock.portions} portions',
      ),
    };
  }
}
