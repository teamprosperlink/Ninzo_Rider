import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../domain/entities/app_permission.dart';
import '../../domain/repositories/permission_repository.dart';

/// Location through geolocator (also used for tracking); notifications and
/// camera through permission_handler.
class DevicePermissionRepository implements PermissionRepository {
  @override
  Future<PermissionResult> check(AppPermission permission) async {
    if (permission == AppPermission.location) {
      if (!await Geolocator.isLocationServiceEnabled()) return PermissionResult.serviceOff;
      return _fromGeolocator(await Geolocator.checkPermission());
    }
    return _fromHandler(await _handler(permission).status);
  }

  @override
  Future<PermissionResult> request(AppPermission permission) async {
    if (permission == AppPermission.location) {
      if (!await Geolocator.isLocationServiceEnabled()) return PermissionResult.serviceOff;
      return _settled(permission, () async => _fromGeolocator(await Geolocator.requestPermission()));
    }
    return _settled(permission, () async => _fromHandler(await _handler(permission).request()));
  }

  /// Runs a system permission request and makes sure it finishes.
  ///
  /// When Android cancels a request (the dialog is interrupted, or another
  /// request is still in flight) it reports an empty result, and both
  /// geolocator and permission_handler then never complete their future. So
  /// if no dialog shows up, or the app comes back to the foreground without an
  /// answer, the current status is read instead.
  Future<PermissionResult> _settled(AppPermission permission, Future<PermissionResult> Function() run) async {
    final result = Completer<PermissionResult>();
    var dialogShown = false;
    Future<void> fallBack() async {
      if (result.isCompleted) return;
      final status = await check(permission);
      if (!result.isCompleted) result.complete(status);
    }

    final lifecycle = AppLifecycleListener(
      onInactive: () => dialogShown = true,
      onResume: () => Future<void>.delayed(const Duration(milliseconds: 800), fallBack),
    );
    final noDialog = Timer(const Duration(seconds: 2), () {
      if (!dialogShown) fallBack();
    });
    run().then((r) => result.isCompleted ? null : result.complete(r), onError: (Object _) => fallBack());
    try {
      return await result.future;
    } finally {
      noDialog.cancel();
      lifecycle.dispose();
    }
  }

  @override
  Future<void> openSettings(AppPermission permission) async {
    if (permission == AppPermission.location && !await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      await ph.openAppSettings();
    }
  }

  static ph.Permission _handler(AppPermission p) => switch (p) {
    AppPermission.location => ph.Permission.locationWhenInUse,
    AppPermission.notifications => ph.Permission.notification,
    AppPermission.camera => ph.Permission.camera,
  };

  static PermissionResult _fromGeolocator(LocationPermission p) => switch (p) {
    LocationPermission.always || LocationPermission.whileInUse => PermissionResult.granted,
    LocationPermission.deniedForever => PermissionResult.blocked,
    _ => PermissionResult.denied,
  };

  static PermissionResult _fromHandler(ph.PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) return PermissionResult.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return PermissionResult.blocked;
    return PermissionResult.denied;
  }
}
