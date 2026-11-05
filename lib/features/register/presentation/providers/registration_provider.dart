import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_state_providers.dart';
import '../../di/register_di.dart';
import '../../domain/entities/rider_application.dart';

/// The signed-in rider's application, or null before their details are
/// saved (or when signed out).
final registrationProvider = StreamProvider<RiderApplication?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(watchRegistrationUseCaseProvider)(uid);
});
