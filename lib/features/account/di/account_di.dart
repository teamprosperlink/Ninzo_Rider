import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_mode.dart';
import '../../../core/di/firebase_providers.dart';
import '../data/repositories/demo_user_repository.dart';
import '../data/repositories/firestore_user_repository.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/usecases/watch_user.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => kDemoMode ? DemoUserRepository() : FirestoreUserRepository(ref.watch(firestoreProvider)),
);

final watchUserUseCaseProvider = Provider((ref) => WatchUser(ref.watch(userRepositoryProvider)));
