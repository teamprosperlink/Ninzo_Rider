import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/widgets/status_views.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../widgets/demo_stock_controls.dart';
import 'lot_alert_page.dart';
import 'manual_count_page.dart';
import 'scan_stock_page.dart';
import 'scans_saved_page.dart';
import 'stock_list_page.dart';

/// Scanning stock onto the scooter (Figma Section 8): the screen for the view
/// model's state.
class StockFlowPage extends ConsumerWidget {
  const StockFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stockFlowViewModelProvider);
    if (state.loading || state.tally == null) return const BlankScreen();
    final page = switch (state.screen) {
      StockScreen.scan => const ScanStockPage(),
      StockScreen.list => const StockListPage(),
      StockScreen.manual => const ManualCountPage(),
      StockScreen.saved => const ScansSavedPage(),
      StockScreen.lotAlert => const LotAlertPage(),
    };
    if (!kDemoMode) return page;
    return Stack(children: [page, const DemoStockControls()]);
  }
}
