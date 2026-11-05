import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_mode.dart';
import '../../../../core/config/demo_data.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/scan_outcome.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../widgets/stock_scanner.dart';
import '../widgets/stock_widgets.dart';

/// Stock 01 scanning; 02, 12 with a toast; 04, 10, 11 with a warning and
/// "Scan again"; 09 with the camera off.
class ScanStockPage extends ConsumerStatefulWidget {
  const ScanStockPage({super.key});

  @override
  ConsumerState<ScanStockPage> createState() => _ScanStockPageState();
}

class _ScanStockPageState extends ConsumerState<ScanStockPage> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed) ref.read(stockFlowViewModelProvider.notifier).recheckCamera();
  }

  static (String, String) _warningText(ScanOutcome warning) => switch (warning) {
    ScanAlreadyScanned(:final item) => (
      'This item is already scanned',
      '${item.name} is already on your list. Scan a different item.',
    ),
    ScanOverLoad(:final item) => (
      'That’s more than today’s load',
      item.quantity == 1
          ? 'You’ve already scanned the ${item.name}. Scan a different item.'
          : 'You’ve already scanned all ${item.quantity} ${item.name}s. Scan a different item.',
    ),
    _ => (
      'This item isn’t in today’s load',
      'Check the label and scan again. Only items in today’s load can go on your scooter.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockFlowViewModelProvider);
    final vm = ref.read(stockFlowViewModelProvider.notifier);
    final tally = state.tally!;
    final cameraOn = state.cameraOn;
    final warning = state.warning;
    final toast = switch (state.toast) {
      CheckingToast() => 'Checking item…',
      AddedToast(:final name, :final loaded, :final total) => '$name added · $loaded of $total',
      null => null,
    };
    final scanner = ref.watch(stockScannerProvider);

    return RiderScaffold(
      title: 'Scan stock',
      onBack: vm.back,
      headerPadding: RiderHeader.flowPadding,
      backSize: 48,
      backBordered: true,
      trailing: cameraOn
          ? RiderLink('Manual', onPressed: vm.showManual, style: RiderText.link, padding: EdgeInsets.zero)
          : null,
      bottomPadding: stockActionsPadding,
      bottom: [
        if (toast != null)
          Padding(padding: const EdgeInsets.only(bottom: 16), child: RiderToast(toast)),
        if (!cameraOn)
          RiderButton.secondary('Enter counts instead', onPressed: vm.showManual)
        else if (warning != null)
          RiderButton('Scan again', onPressed: vm.scanAgain)
        else
          RiderButton.secondary('View list', onPressed: vm.showList),
      ],
      children: [
        Text(
          cameraOn
              ? 'Scan each item’s QR code to confirm it’s on your scooter.'
              : 'Allow camera access to scan, or enter counts by hand.',
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: 16),
        RiderViewfinder(
          caption: cameraOn ? 'Point at the item QR code' : 'Turn on camera to scan',
          radius: RiderRadius.field,
          cornerStroke: 4,
          preview: cameraOn ? scanner(context, vm.onCode, vm.cameraFailed) : null,
          // Demo mode: no real labels to point at, so each tap "scans" the
          // next sample code.
          onTap: !cameraOn
              ? vm.turnOnCamera
              : kDemoMode
              ? () => vm.demoNextScan(DemoData.scanScript)
              : null,
        ),
        const SizedBox(height: 16),
        if (warning != null && cameraOn)
          () {
            final (title, message) = _warningText(warning);
            return RiderWarningCard(
              title: title,
              message: message,
            );
          }()
        else
          StockProgress(label: 'Portions loaded', done: tally.portionsLoaded, total: tally.portions),
      ],
    );
  }
}
