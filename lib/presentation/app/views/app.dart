import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/providers/auth_state_providers.dart';
import '../../intro/viewmodels/intro_flow_view_model.dart';
import '../../shift/viewmodels/shift_push_controller.dart';
import '../../../routing/app_router.dart';
import '../../../core/constants/app_strings.dart';

class NinzoRiderApp extends StatelessWidget {
  const NinzoRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.ninzorider,
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
          loading: () => appStagePage(AppStage.splash, flow),
          error: (_, _) => SilentRetry(onRetry: () => retrySession(ref), child: appStagePage(AppStage.splash, flow)),
          data: (stage) => appStagePage(stage, flow),
        );
  }
}
