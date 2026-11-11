import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../shift/providers/shift_providers.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/stock.dart';
import '../../../domain/entities/online_status.dart';
import '../../../core/constants/app_durations.dart';

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

  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  void start() {
    _timer?.cancel();
    state = true;
    _timer = Timer(AppDurations.spotConfirmedHold, cancel);
  }

  void cancel() {
    _timer?.cancel();
    state = false;
  }
}

final spotJustConfirmedProvider = NotifierProvider<SpotJustConfirmed, bool>(SpotJustConfirmed.new);
