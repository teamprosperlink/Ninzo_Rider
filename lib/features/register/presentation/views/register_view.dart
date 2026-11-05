import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/registration_provider.dart';
import '../viewmodels/register_view_model.dart';
import 'area_page.dart';
import 'details_page.dart';
import 'documents_page.dart';
import 'photo_pages.dart';
import 'status_pages.dart';

/// Register 01–16 (see [RegisterScreen] for which frames each screen covers).
class RegisterView extends ConsumerWidget {
  const RegisterView({
    super.key,
    required this.onBack,
    required this.onSignIn,
  });

  /// Back arrow on Register 01 while signed out (to Welcome).
  final VoidCallback onBack;

  /// "Sign in" links while signed out.
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(registerViewModelProvider.notifier);
    ref.watch(registerViewModelProvider);
    final application = ref.watch(registrationProvider).value;
    final signedIn = vm.signedIn;
    return switch (vm.screenFor(application)) {
      RegisterScreen.details => DetailsPage(
        onBack: signedIn ? vm.signOut : onBack,
        onSignIn: signedIn ? vm.signOut : onSignIn,
        onContinue: vm.continueDetails,
      ),
      RegisterScreen.area => const AreaPage(),
      RegisterScreen.documents => DocumentsPage(application: application!),
      RegisterScreen.photo => const PhotoPage(),
      RegisterScreen.review => const PhotoReviewPage(),
      RegisterScreen.status => StatusPage(application: application!),
    };
  }
}
