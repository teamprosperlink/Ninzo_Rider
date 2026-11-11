/// Remembers which onboarding steps were already shown on this phone.
abstract interface class IntroRepository {
  Future<bool> permissionsSeen();

  Future<void> markPermissionsSeen();
}
