import '../repositories/auth_repository.dart';
import '../repositories/session_repository.dart';

/// Run at app start. Signs out a rider who didn't tick "Keep me signed in",
/// and reports whether a session ended without the rider signing out
/// (another phone, timeout, or not kept), which shows "Signed out".
class RestoreSession {
  const RestoreSession(this._auth, this._session);

  final AuthRepository _auth;
  final SessionRepository _session;

  /// True when the rider should see "You've been signed out".
  Future<bool> call() async {
    final user = await _auth.authStateChanges().first;
    if (user != null) {
      if (await _session.keepSignedIn()) {
        await _session.setWasSignedIn(true);
        return false;
      }
      await _session.setWasSignedIn(false);
      await _auth.signOut();
      return true;
    }
    return sessionEnded();
  }

  /// Whether the session ended on its own; clears the flag.
  Future<bool> sessionEnded() async {
    final ended = await _session.wasSignedIn();
    if (ended) await _session.setWasSignedIn(false);
    return ended;
  }
}
