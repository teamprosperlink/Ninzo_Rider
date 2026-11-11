import 'package:flutter/services.dart';

import '../../domain/repositories/device_status_repository.dart';
import '../../domain/repositories/shift_end_repositories.dart';

/// Location from the phone's status; the date settings over the app's own
/// channel to Android (`MainActivity`). Elsewhere the time counts as right.
class PhoneDeviceHealthRepository implements DeviceHealthRepository {
  PhoneDeviceHealthRepository(this._device);

  static const _channel = MethodChannel('ninzo/device');

  final DeviceStatusRepository _device;

  @override
  Future<bool> locationOn() => _device.locationOn();

  @override
  Future<void> openLocationSettings() => _device.openLocationSettings();

  @override
  Future<bool> phoneTimeAutomatic() async {
    try {
      return await _channel.invokeMethod<bool>('autoTime') ?? true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<void> openDateSettings() async {
    try {
      await _channel.invokeMethod<void>('openDateSettings');
    } on MissingPluginException {
      // Nothing to open here.
    } on PlatformException {
      // Nothing to open here.
    }
  }
}

/// The demo's phone: the pill breaks it, and its "settings" fix it.
class DemoDeviceHealthRepository implements DeviceHealthRepository {
  bool location = true;
  bool autoTime = true;

  @override
  Future<bool> locationOn() async => location;

  @override
  Future<bool> phoneTimeAutomatic() async => autoTime;

  @override
  Future<void> openLocationSettings() async => location = true;

  @override
  Future<void> openDateSettings() async => autoTime = true;
}
