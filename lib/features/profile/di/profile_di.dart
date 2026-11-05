import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_mode.dart';
import '../../../core/di/clock_provider.dart';
import '../../../core/di/firebase_providers.dart';
import '../data/repositories/demo_profile_repository.dart';
import '../data/repositories/firestore_profile_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/usecases/profile_usecases.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => kDemoMode ? DemoProfileRepository(ref.watch(clockProvider)) : FirestoreProfileRepository(ref.watch(firestoreProvider)),
);

final watchProfileFactsUseCaseProvider = Provider((ref) => WatchProfileFacts(ref.watch(profileRepositoryProvider)));
final watchRiderNotificationsUseCaseProvider = Provider(
  (ref) => WatchRiderNotifications(ref.watch(profileRepositoryProvider)),
);
final watchShiftRecordsUseCaseProvider = Provider((ref) => WatchShiftRecords(ref.watch(profileRepositoryProvider)));
