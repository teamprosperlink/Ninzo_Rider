import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/repositories/device_status_repository.dart';

/// Battery from battery_plus, location from geolocator.
class PhoneDeviceStatusRepository implements DeviceStatusRepository {
  final _battery = Battery();

  @override
  Future<int> phoneBattery() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      // Unknown (e.g. no battery): don't block the rider.
      return 100;
    }
  }

  @override
  Future<bool> locationOn() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  @override
  Future<void> openLocationSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      final p = await Geolocator.requestPermission();
      if (p == LocationPermission.deniedForever) await Geolocator.openAppSettings();
    }
  }
}
