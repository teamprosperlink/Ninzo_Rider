import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_state_providers.dart';
import '../../../shift/presentation/providers/shift_providers.dart';
import '../../../stock/di/stock_di.dart';
import '../../../stock/domain/entities/stock.dart';
import '../../di/online_di.dart';
import '../../domain/entities/online_status.dart';

/// The backend's values for the online rider.
final onlineStatusProvider = StreamProvider<OnlineStatus>((ref) {
  final uid = ref.watch(currentUidProvider);
  final shiftId = ref.watch(todayShiftProvider.select((s) => s.value?.id));
  if (uid == null || shiftId == null) return Stream.value(const OnlineStatus());
  return ref.watch(watchOnlineStatusUseCaseProvider)(uid, shiftId);
});

/// Today's load (the list on Shift 20).
final scooterItemsProvider = FutureProvider<List<StockItem>>((ref) async {
  final uid = ref.watch(currentUidProvider);
  final shiftId = ref.watch(todayShiftProvider.select((s) => s.value?.id));
  if (uid == null || shiftId == null) return const [];
  final local = await ref.read(loadStockUseCaseProvider)(uid, shiftId);
  return local.manifest?.items ?? const [];
});

/// Shift 25: the rider has just confirmed the spot; the sheet says so for a
/// moment before Shift 26.
class SpotJustConfirmed extends Notifier<bool> {
  /// How long Shift 25 "Online · at spot" stays.
  static const hold = Duration(seconds: 5);

  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  void start() {
    _timer?.cancel();
    state = true;
    _timer = Timer(hold, cancel);
  }

  void cancel() {
    _timer?.cancel();
    state = false;
  }
}

final spotJustConfirmedProvider = NotifierProvider<SpotJustConfirmed, bool>(SpotJustConfirmed.new);
