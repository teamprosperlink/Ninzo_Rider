import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/demo_data.dart';
import '../../../../core/di/clock_provider.dart';
import '../../../online/di/online_di.dart';
import '../../../online/presentation/widgets/demo_online_controls.dart';
import '../../domain/entities/restock.dart';

/// Demo mode only, not part of the design: plays the backend on Refill 01.
class DemoOutOfStockPill extends ConsumerWidget {
  const DemoOutOfStockPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Positioned(
    right: 16,
    bottom: 200,
    child: DemoPill(
      key: const Key('demo_out_of_stock'),
      label: 'Demo: Out of stock',
      onTap: () {
        final repository = ref.read(demoOnlineProvider);
        if (repository == null) return;
        repository.set(repository.status.copyWith(sold: repository.status.sold + 1));
      },
    ),
  );
}

/// Demo mode only, not part of the design: plays the backend on Restock 01, 03.
class DemoRestockPill extends ConsumerWidget {
  const DemoRestockPill({super.key, required this.request});

  final RestockRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(demoOnlineProvider);
    if (repository == null) return const SizedBox.shrink();
    void put(RestockRequest next) => repository.set(repository.status.copyWith(restock: () => next));
    final (key, label, play) = switch (request.stage) {
      RestockStage.suggested when request.expiresAt == null => (
        'demo_restock_expire',
        'Demo: Suggestion expired',
        () => put(request.copyWith(expiresAt: () => ref.read(clockProvider)())),
      ),
      RestockStage.inProgress when request.lines.isNotEmpty && RestockRules.total(request.lines) > DemoData.shortCanGive => (
        'demo_restock_short',
        'Demo: Hub is short',
        () {
          final line = request.lines.firstWhere((l) => l.quantity > 0);
          put(
            request.copyWith(
              stage: RestockStage.hubShort,
              shortage: () => RestockShortage(
                itemName: line.name,
                asked: line.quantity,
                canGive: DemoData.shortCanGive,
                otherHubName: DemoData.otherHub,
                otherHubKm: DemoData.otherHubKm,
                otherHubHas: DemoData.otherHubHas,
              ),
            ),
          );
        },
      ),
      _ => (null, '', () {}),
    };
    if (key == null) return const SizedBox.shrink();
    return Positioned(
      right: 16,
      bottom: 220,
      child: DemoPill(key: Key(key), label: label, onTap: play),
    );
  }
}
