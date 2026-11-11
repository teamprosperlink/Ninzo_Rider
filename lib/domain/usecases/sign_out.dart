import '../repositories/auth_repository.dart';
import '../repositories/session_repository.dart';

/// The rider signs out themselves (not a session that ended on its own).
class SignOut {
  const SignOut(this._repo, this._session);

  final AuthRepository _repo;
  final SessionRepository _session;

  Future<void> call() async {
    await _session.setWasSignedIn(false);
    await _repo.signOut();
  }
}
