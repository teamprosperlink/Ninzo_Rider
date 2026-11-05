import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/providers/auth_state_providers.dart';
import '../features/intro/presentation/viewmodels/intro_flow_view_model.dart';
import '../features/register/presentation/providers/registration_provider.dart';

/// Which root screen shows.
enum AppStage {
  /// Onboard 01, while the session is restored.
  splash,

  /// Onboard 02.
  welcome,

  /// Onboard 03–06.
  permissions,

  /// Login 01–16.
  login,

  /// Onboard 07.
  signedOut,

  /// Register 01–16: new rider details (signed out), then, once the number
  /// is verified, documents, review and approval until the rider has seen
  /// their spot.
  register,

  /// The rider's day (Shift 01–12, 51–53): Home, the pre-shift checklist
  /// and the hub trip; later sections continue from there.
  home,
}

/// Which root screen to show.
final appStageProvider = Provider<AsyncValue<AppStage>>((ref) {
  final startup = ref.watch(appStartupProvider);
  if (startup.hasError) return AsyncError(startup.error!, startup.stackTrace!);
  if (!startup.hasValue) return const AsyncData(AppStage.splash);

  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return AsyncError(auth.error!, auth.stackTrace!);
  if (!auth.hasValue) return const AsyncData(AppStage.splash);

  if (auth.value == null) {
    return AsyncData(switch (ref.watch(introFlowProvider).screen) {
      IntroScreen.welcome => AppStage.welcome,
      IntroScreen.permission => AppStage.permissions,
      IntroScreen.login => AppStage.login,
      IntroScreen.signedOut => AppStage.signedOut,
      IntroScreen.register => AppStage.register,
    });
  }
  // "Verified!" stays up until the rider taps Start shift.
  if (ref.watch(loginHoldProvider)) return const AsyncData(AppStage.login);

  final application = ref.watch(registrationProvider);
  return application.whenData((a) => a != null && a.isActive ? AppStage.home : AppStage.register);
});

/// Re-subscribes to the session after a load error.
void retrySession(WidgetRef ref) => ref
  ..invalidate(appStartupProvider)
  ..invalidate(authStateProvider)
  ..invalidate(registrationProvider);
