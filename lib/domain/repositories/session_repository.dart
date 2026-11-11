/// Session preferences kept on this phone.
abstract interface class SessionRepository {
  /// "Keep me signed in on this phone". Defaults to true.
  Future<bool> keepSignedIn();

  Future<void> setKeepSignedIn(bool keep);

  /// Whether a rider was signed in last time and didn't sign out themselves.
  Future<bool> wasSignedIn();

  Future<void> setWasSignedIn(bool value);
}
