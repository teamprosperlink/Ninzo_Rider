import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_mode.dart';
import '../../../core/constants/demo_data.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/scan_outcome.dart';
import '../viewmodels/stock_flow_view_model.dart';
import '../widgets/stock_scanner.dart';
import '../widgets/stock_widgets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';

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
      AppStrings.thisItemIsAlreadyScanned,
      AppStrings.isAlreadyOnYourListScan(item.name),
    ),
    ScanOverLoad(:final item) => (
      AppStrings.thatSMoreThanTodayS,
      item.quantity == 1
          ? AppStrings.youVeAlreadyScannedTheScan(item.name)
          : AppStrings.youVeAlreadyScannedAllS(item.quantity, item.name),
    ),
    _ => (
      AppStrings.thisItemIsnTInToday,
      AppStrings.checkTheLabelAndScanAgain,
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
      CheckingToast() => AppStrings.checkingItem,
      AddedToast(:final name, :final loaded, :final total) => AppStrings.addedOf(name, loaded, total),
      null => null,
    };
    final scanner = ref.watch(stockScannerProvider);

    return RiderScaffold(
      title: AppStrings.scanStock,
      onBack: vm.back,
      headerPadding: RiderHeader.flowPadding,
      backSize: AppSizes.s48,
      backBordered: true,
      trailing: cameraOn
          ? RiderLink(AppStrings.manual, onPressed: vm.showManual, style: RiderText.link, padding: EdgeInsets.zero)
          : null,
      bottomPadding: RiderLayout.stockActionsPadding,
      bottom: [
        if (toast != null)
          Padding(padding: const EdgeInsets.only(bottom: AppSizes.s16), child: RiderToast(toast)),
        if (!cameraOn)
          RiderButton.secondary(AppStrings.enterCountsInstead, onPressed: vm.showManual)
        else if (warning != null)
          RiderButton(AppStrings.scanAgain, onPressed: vm.scanAgain)
        else
          RiderButton.secondary(AppStrings.viewList, onPressed: vm.showList),
      ],
      children: [
        Text(
          cameraOn
              ? AppStrings.scanEachItemSQrCode
              : AppStrings.allowCameraAccessToScanOr,
          style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
        ),
        const SizedBox(height: AppSizes.s16),
        RiderViewfinder(
          caption: cameraOn ? AppStrings.pointAtTheItemQrCode : AppStrings.turnOnCameraToScan,
          radius: RiderRadius.field,
          cornerStroke: AppSizes.s4,
          preview: cameraOn ? scanner(context, vm.onCode, vm.cameraFailed) : null,
          // Demo mode: no real labels to point at, so each tap "scans" the
          // next sample code.
          onTap: !cameraOn
              ? vm.turnOnCamera
              : kDemoControls
              ? () => vm.demoNextScan(DemoData.scanScript)
              : null,
        ),
        const SizedBox(height: AppSizes.s16),
        if (warning != null && cameraOn)
          () {
            final (title, message) = _warningText(warning);
            return RiderWarningCard(
              title: title,
              message: message,
            );
          }()
        else
          StockProgress(label: AppStrings.portionsLoaded, done: tally.portionsLoaded, total: tally.portions),
      ],
    );
  }
}
