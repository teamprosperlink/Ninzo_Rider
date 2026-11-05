import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ride.dart';
import 'driver_controller.dart';
import 'rider_controller.dart';

/// App-wide session. Stored on the device until a backend (e.g. Firebase)
/// is connected. The controllers live here so rider and driver data
/// survive switching between modes.
class AppSession {
  static const _phoneKey = 'phone';
  static const _modeKey = 'mode';
  static const _driverProfileKey = 'driver_profile';

  static late SharedPreferences _prefs;
  static final rider = RiderController();
  static final driver = DriverController();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    rider.load(_prefs);
    driver.load(_prefs);
    driver.vehicleType = driverProfile?.vehicleType ?? VehicleType.bike;
  }

  static String get phone => _prefs.getString(_phoneKey) ?? '';
  static bool get isLoggedIn => phone.isNotEmpty;

  static AppMode get mode {
    final name = _prefs.getString(_modeKey);
    return AppMode.values.where((m) => m.name == name).firstOrNull ?? AppMode.rider;
  }

  /// True while the user has a ride in progress in either mode;
  /// switching modes is blocked then so a user never rides with themselves.
  static bool get hasActiveRide => rider.ride != null || driver.activeRide != null;

  static Future<void> login(String phone) => _prefs.setString(_phoneKey, phone);

  static Future<void> setMode(AppMode mode) async {
    if (mode == AppMode.rider) driver.setOnline(false);
    await _prefs.setString(_modeKey, mode.name);
  }

  static DriverProfile? get driverProfile {
    final raw = _prefs.getString(_driverProfileKey);
    if (raw == null) return null;
    try {
      return DriverProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  static Future<void> saveDriverProfile(DriverProfile profile) async {
    driver.vehicleType = profile.vehicleType;
    await _prefs.setString(_driverProfileKey, jsonEncode(profile.toJson()));
  }

  /// Clears everything stored for this account on the device.
  static Future<void> logout() async {
    rider.reset();
    driver.reset();
    await _prefs.clear();
  }
}
