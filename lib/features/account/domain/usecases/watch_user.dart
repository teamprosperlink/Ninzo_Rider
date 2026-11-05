import '../entities/app_user.dart';
import '../repositories/user_repository.dart';

class WatchUser {
  const WatchUser(this._repo);

  final UserRepository _repo;

  Stream<AppUser?> call(String uid) => _repo.watchUser(uid);
}
