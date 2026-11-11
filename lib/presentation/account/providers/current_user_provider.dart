import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/app_user.dart';

/// Profile of the signed-in user; null when signed out or not signed up yet.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(watchUserUseCaseProvider)(uid);
});
