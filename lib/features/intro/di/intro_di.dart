import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/device_permission_repository.dart';
import '../data/repositories/prefs_intro_repository.dart';
import '../domain/repositories/intro_repository.dart';
import '../domain/repositories/permission_repository.dart';
import '../domain/usecases/permission_usecases.dart';

/// Permissions are the phone's own, so demo mode uses the real ones too.
final permissionRepositoryProvider = Provider<PermissionRepository>((ref) => DevicePermissionRepository());
final introRepositoryProvider = Provider<IntroRepository>((ref) => PrefsIntroRepository());

final requestPermissionUseCaseProvider = Provider((ref) => RequestPermission(ref.watch(permissionRepositoryProvider)));
final checkPermissionUseCaseProvider = Provider((ref) => CheckPermission(ref.watch(permissionRepositoryProvider)));
final openPermissionSettingsUseCaseProvider = Provider(
  (ref) => OpenPermissionSettings(ref.watch(permissionRepositoryProvider)),
);
final permissionsIntroUseCaseProvider = Provider((ref) => PermissionsIntro(ref.watch(introRepositoryProvider)));

/// How long the splash stays up at least.
final splashDurationProvider = Provider((ref) => const Duration(milliseconds: 1500));
