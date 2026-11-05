import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/status_views.dart';
import '../features/auth/presentation/providers/auth_state_providers.dart';
import '../features/auth/presentation/views/login_view.dart';
import '../features/intro/presentation/viewmodels/intro_flow_view_model.dart';
import '../features/intro/presentation/views/permission_view.dart';
import '../features/intro/presentation/views/signed_out_view.dart';
import '../features/intro/presentation/views/splash_view.dart';
import '../features/intro/presentation/views/welcome_view.dart';
import '../features/shift/presentation/viewmodels/shift_push_controller.dart';
import '../features/shift/presentation/views/shift_flow_view.dart';
import '../features/register/presentation/views/register_view.dart';
import 'app_stage.dart';

class NinzoRiderApp extends StatelessWidget {
  const NinzoRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NinzoRider',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AppGate(),
    );
  }
}

/// Shows the root screen for the current [AppStage].
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Signed out while the app is open: Welcome, or "Signed out" when the
    // rider didn't ask for it.
    ref.listen(authStateProvider, (previous, next) {
      if (previous?.value != null && next.hasValue && next.value == null) {
        ref.read(introFlowProvider.notifier).onSignedOut();
      }
    });
    // Shift pushes follow the rider, also when they sign out.
    ref.watch(shiftPushControllerProvider);
    final flow = ref.read(introFlowProvider.notifier);
    return ref.watch(appStageProvider).when(
          loading: () => const SplashView(),
          error: (_, _) => SilentRetry(onRetry: () => retrySession(ref), child: const SplashView()),
          data: (stage) => switch (stage) {
            AppStage.splash => const SplashView(),
            AppStage.welcome => WelcomeView(onSignIn: flow.signIn, onRegister: flow.register),
            AppStage.permissions => const PermissionView(),
            AppStage.login => LoginView(
                onBack: flow.backToWelcome,
                onRegister: flow.register,
              ),
            AppStage.signedOut => SignedOutView(onSignIn: flow.signIn),
            AppStage.register => RegisterView(
                onBack: flow.backToWelcome,
                onSignIn: flow.signIn,
              ),
            AppStage.home => const ShiftFlowView(),
          },
        );
  }
}
