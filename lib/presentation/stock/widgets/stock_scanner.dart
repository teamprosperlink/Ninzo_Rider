import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/clock_provider.dart';
import '../../../domain/usecases/stock_usecases.dart';

/// Builds the live camera picture. [onCode] gets each QR code read;
/// [onUnavailable] says the camera can't be used.
typedef StockScannerBuilder =
    Widget Function(BuildContext context, ValueChanged<String> onCode, VoidCallback onUnavailable);

/// The camera behind the viewfinder; tests swap it, as there's no camera to
/// read codes from.
final stockScannerProvider = Provider<StockScannerBuilder>(
  (ref) =>
      (context, onCode, onUnavailable) => QrCameraPreview(onCode: onCode, onUnavailable: onUnavailable),
);

/// The rear camera, reading QR codes only.
class QrCameraPreview extends ConsumerStatefulWidget {
  const QrCameraPreview({super.key, required this.onCode, required this.onUnavailable});

  final ValueChanged<String> onCode;
  final VoidCallback onUnavailable;

  @override
  ConsumerState<QrCameraPreview> createState() => _QrCameraPreviewState();
}

class _QrCameraPreviewState extends ConsumerState<QrCameraPreview> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  late final _filter = RepeatCodeFilter(ref.read(clockProvider));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && _filter.accept(raw)) widget.onCode(raw);
    }
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _controller,
    onDetect: _onDetect,
    placeholderBuilder: (_) => const SizedBox.shrink(),
    errorBuilder: (context, error) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onUnavailable());
      return const SizedBox.shrink();
    },
  );
}
