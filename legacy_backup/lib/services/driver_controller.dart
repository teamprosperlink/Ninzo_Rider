import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_data.dart';
import '../models/ride.dart';

/// Drives the driver-side flow. Incoming ride requests are simulated
/// while the driver is online.
class DriverController extends ChangeNotifier {
  static const requestTimeoutSeconds = 15;
  static const _earningsKey = 'driver_earnings';
  static const _tripsKey = 'driver_trips';
  static const _statsDateKey = 'driver_stats_date';

  final _rand = Random();
  Timer? _timer;
  SharedPreferences? _prefs;
  String _statsDate = _today();

  bool online = false;
  Ride? request;
  int requestSecondsLeft = 0;
  Ride? activeRide;
  double earningsToday = 0;
  int tripsToday = 0;

  /// Requests are generated for the vehicle the driver registered.
  VehicleType vehicleType = VehicleType.bike;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void load(SharedPreferences prefs) {
    _prefs = prefs;
    _statsDate = prefs.getString(_statsDateKey) ?? _today();
    earningsToday = prefs.getDouble(_earningsKey) ?? 0;
    tripsToday = prefs.getInt(_tripsKey) ?? 0;
    _rollOverIfNewDay();
  }

  void _rollOverIfNewDay() {
    if (_statsDate == _today()) return;
    _statsDate = _today();
    earningsToday = 0;
    tripsToday = 0;
  }

  void reset() {
    _timer?.cancel();
    online = false;
    request = null;
    activeRide = null;
    earningsToday = 0;
    tripsToday = 0;
    vehicleType = VehicleType.bike;
    notifyListeners();
  }

  void setOnline(bool value) {
    online = value;
    _timer?.cancel();
    request = null;
    if (online) _scheduleRequest();
    notifyListeners();
  }

  void _scheduleRequest() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: 4 + _rand.nextInt(4)), () {
      if (!online || activeRide != null) return;
      final places = [...MockData.places]..shuffle(_rand);
      request = Ride(
        id: 'NR${DateTime.now().millisecondsSinceEpoch}',
        pickup: places[0],
        drop: places[1],
        vehicle: vehicleType,
        otp: (1000 + _rand.nextInt(9000)).toString(),
        riderName: MockData.riderNames[_rand.nextInt(MockData.riderNames.length)],
      );
      requestSecondsLeft = requestTimeoutSeconds;
      notifyListeners();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        requestSecondsLeft--;
        if (requestSecondsLeft <= 0) {
          reject();
        } else {
          notifyListeners();
        }
      });
    });
  }

  void accept() {
    _timer?.cancel();
    activeRide = request?..status = RideStatus.driverAssigned;
    request = null;
    notifyListeners();
  }

  void reject() {
    _timer?.cancel();
    request = null;
    notifyListeners();
    if (online) _scheduleRequest();
  }

  void markArrived() {
    activeRide?.status = RideStatus.driverArrived;
    notifyListeners();
  }

  /// Returns false when the OTP given by the rider does not match.
  bool startTrip(String otp) {
    final ride = activeRide;
    if (ride == null || otp.trim() != ride.otp) return false;
    ride.status = RideStatus.inProgress;
    notifyListeners();
    return true;
  }

  void completeTrip() {
    final ride = activeRide;
    if (ride == null) return;
    ride.status = RideStatus.completed;
    _rollOverIfNewDay();
    earningsToday += ride.fare;
    tripsToday++;
    _prefs
      ?..setDouble(_earningsKey, earningsToday)
      ..setInt(_tripsKey, tripsToday)
      ..setString(_statsDateKey, _statsDate);
    notifyListeners();
  }

  void finishTrip() {
    activeRide = null;
    notifyListeners();
    if (online) _scheduleRequest();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
