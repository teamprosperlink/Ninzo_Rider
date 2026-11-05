import '../entities/app_permission.dart';
import '../repositories/intro_repository.dart';
import '../repositories/permission_repository.dart';

/// Asks for a permission. Location also needs location services on; when
/// they are off the result is [PermissionResult.serviceOff].
class RequestPermission {
  const RequestPermission(this._repo);

  final PermissionRepository _repo;

  Future<PermissionResult> call(AppPermission permission) async {
    final current = await _repo.check(permission);
    if (current.isGranted || current == PermissionResult.serviceOff || current == PermissionResult.blocked) {
      return current;
    }
    return _repo.request(permission);
  }
}

/// Checks a permission again ("I've turned it on").
class CheckPermission {
  const CheckPermission(this._repo);

  final PermissionRepository _repo;

  Future<PermissionResult> call(AppPermission permission) => _repo.check(permission);
}

class OpenPermissionSettings {
  const OpenPermissionSettings(this._repo);

  final PermissionRepository _repo;

  Future<void> call(AppPermission permission) => _repo.openSettings(permission);
}

/// The permission screens show once per phone.
class PermissionsIntro {
  const PermissionsIntro(this._repo);

  final IntroRepository _repo;

  Future<bool> shouldShow() async => !await _repo.permissionsSeen();

  Future<void> finish() => _repo.markPermissionsSeen();

  /// The permission after [current], or null when done.
  static AppPermission? next(AppPermission current) {
    final i = current.index + 1;
    return i < AppPermission.values.length ? AppPermission.values[i] : null;
  }
}
