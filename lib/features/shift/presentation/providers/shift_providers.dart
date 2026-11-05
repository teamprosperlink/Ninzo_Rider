import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/clock_provider.dart';
import '../../../auth/presentation/providers/auth_state_providers.dart';
import '../../../register/presentation/providers/registration_provider.dart';
import '../../di/shift_di.dart';
import '../../domain/entities/shift.dart';

/// Today's shift, or null when the rider has none.
final todayShiftProvider = StreamProvider<Shift?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(watchTodayShiftUseCaseProvider)(uid);
});

/// Ticks every 15 seconds so Home turns from "Your stock is ready" (Shift
/// 04) to "Start riding" (05) when the shift begins.
final _shiftTickProvider = StreamProvider<int>((ref) => Stream.periodic(const Duration(seconds: 15), (i) => i));

/// The current time; screens that watch it rebuild on each tick.
DateTime watchShiftClock(WidgetRef ref) {
  ref.watch(_shiftTickProvider);
  return ref.read(clockProvider)();
}

final _secondTickProvider = StreamProvider<int>((ref) => Stream.periodic(const Duration(seconds: 1), (i) => i));

/// The current time, for screens with a running clock (Shift 37, 44, 45).
DateTime watchSecondClock(WidgetRef ref) {
  ref.watch(_secondTickProvider);
  return ref.read(clockProvider)();
}

/// The rider's first name, as on Home ("Ravi").
final riderFirstNameProvider = Provider<String>((ref) {
  final name = ref.watch(registrationProvider).value?.name.trim() ?? '';
  return name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
});
