import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/profile.dart';

final profileFactsProvider = StreamProvider.autoDispose<ProfileFacts>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const ProfileFacts());
  return ref.watch(watchProfileFactsUseCaseProvider)(uid);
});

final riderNotificationsProvider = StreamProvider.autoDispose<List<RiderNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(watchRiderNotificationsUseCaseProvider)(uid);
});

final shiftRecordsProvider = StreamProvider.autoDispose<List<ShiftRecord>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(watchShiftRecordsUseCaseProvider)(uid);
});

/// The help centre's questions and answers (Profile 02).
final helpArticlesProvider = StreamProvider.autoDispose<List<HelpArticle>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(watchHelpUseCaseProvider)(uid);
});
