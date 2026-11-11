import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/widgets/status_views.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../widgets/demo_stock_controls.dart';
import '../../../routing/app_router.dart';

/// Scanning stock onto the scooter (Figma Section 8): the screen for the view
/// model's state.
class StockFlowPage extends ConsumerWidget {
  const StockFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockFlowViewModelProvider);
    if (state.loading || state.tally == null) return const BlankScreen();
    final page = stockScreenPage(state.screen);
    if (!kDemoControls) return page;
    return Stack(children: [page, const DemoStockControls()]);
  }
}
