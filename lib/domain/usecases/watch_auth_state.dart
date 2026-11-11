import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class WatchAuthState {
  const WatchAuthState(this._repo);

  final AuthRepository _repo;

  Stream<AuthUser?> call() => _repo.authStateChanges();
}
