import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_mode.dart';
import '../../../core/di/firebase_providers.dart';
import '../data/repositories/demo_auth_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../data/repositories/firestore_rider_directory.dart';
import '../data/repositories/prefs_session_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/rider_directory.dart';
import '../domain/repositories/session_repository.dart';
import '../domain/usecases/request_login_code.dart';
import '../domain/usecases/restore_session.dart';
import '../domain/usecases/sign_out.dart';
import '../domain/usecases/verify_otp.dart';
import '../domain/usecases/watch_auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => kDemoMode ? DemoAuthRepository() : FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);

final riderDirectoryProvider = Provider<RiderDirectory>(
  (ref) => kDemoMode ? DemoRiderDirectory() : FirestoreRiderDirectory(ref.watch(firestoreProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>((ref) => PrefsSessionRepository());

final watchAuthStateUseCaseProvider = Provider((ref) => WatchAuthState(ref.watch(authRepositoryProvider)));
final requestLoginCodeUseCaseProvider = Provider(
  (ref) => RequestLoginCode(ref.watch(authRepositoryProvider), ref.watch(riderDirectoryProvider)),
);
final verifyOtpUseCaseProvider = Provider(
  (ref) => VerifyOtp(ref.watch(authRepositoryProvider), ref.watch(sessionRepositoryProvider)),
);
final signOutUseCaseProvider = Provider(
  (ref) => SignOut(ref.watch(authRepositoryProvider), ref.watch(sessionRepositoryProvider)),
);
final restoreSessionUseCaseProvider = Provider(
  (ref) => RestoreSession(ref.watch(authRepositoryProvider), ref.watch(sessionRepositoryProvider)),
);
