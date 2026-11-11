import '../../../core/constants/app_mode.dart';
import '../../account/providers/current_user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/clock_provider.dart';
import '../../auth/providers/auth_state_providers.dart';
import '../../register/providers/registration_provider.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/shift.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_patterns.dart';

/// Today's shift, or null when the rider has none.
final todayShiftProvider = StreamProvider<Shift?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(watchTodayShiftUseCaseProvider)(uid);
});

/// Ticks every 15 seconds so Home turns from "Your stock is ready" (Shift
/// 04) to "Start riding" (05) when the shift begins.
final _shiftTickProvider = StreamProvider<int>((ref) => Stream.periodic(AppDurations.seconds15, (i) => i));

/// The current time; screens that watch it rebuild on each tick.
DateTime watchShiftClock(WidgetRef ref) {
  ref.watch(_shiftTickProvider);
  return ref.read(clockProvider)();
}

final _secondTickProvider = StreamProvider<int>((ref) => Stream.periodic(AppDurations.seconds1, (i) => i));

/// The current time, for screens with a running clock (Shift 37, 44, 45).
DateTime watchSecondClock(WidgetRef ref) {
  ref.watch(_secondTickProvider);
  return ref.read(clockProvider)();
}

/// The rider's first name, as on Home ("Ravi").
final riderFirstNameProvider = Provider<String>((ref) {
  // With the rider API the name is the profile's: it has no registration record.
  final profile = kRiderApi ? ref.watch(currentUserProvider).value?.name.trim() ?? '' : '';
  final name = profile.isNotEmpty ? profile : ref.watch(registrationProvider).value?.name.trim() ?? '';
  return name.isEmpty ? '' : name.split(RegExp(AppPatterns.whitespace)).first;
});
