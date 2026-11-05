import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/auth_di.dart';
import '../../domain/entities/auth_user.dart';

final authStateProvider = StreamProvider<AuthUser?>((ref) => ref.watch(watchAuthStateUseCaseProvider)());

/// Signed-in user's id, or null. Only changes on sign-in and sign-out.
final currentUidProvider = Provider<String?>((ref) => ref.watch(authStateProvider).value?.uid);

/// True while the login screen must stay up after signing in (the
/// "Verified!" sheet), so the app doesn't move on underneath it.
class LoginHold extends Notifier<bool> {
  @override
  bool build() => false;

  void hold(bool value) => state = value;
}

final loginHoldProvider = NotifierProvider<LoginHold, bool>(LoginHold.new);
