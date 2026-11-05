import '../entities/app_permission.dart';

abstract interface class PermissionRepository {
  Future<PermissionResult> check(AppPermission permission);

  /// Shows the system prompt when it can still be shown.
  Future<PermissionResult> request(AppPermission permission);

  /// Opens the phone's settings for [permission] (location settings when
  /// location services are off, otherwise the app's settings page).
  Future<void> openSettings(AppPermission permission);
}
