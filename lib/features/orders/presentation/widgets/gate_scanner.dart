import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../stock/presentation/widgets/stock_scanner.dart';

/// The camera behind the gate's viewfinder (Arrival 01); tests swap it, as
/// there's no camera to read codes from.
final gateScannerProvider = Provider<StockScannerBuilder>(
  (ref) =>
      (context, onCode, onUnavailable) => QrCameraPreview(onCode: onCode, onUnavailable: onUnavailable),
);
