import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_data.dart';
import '../models/ride.dart';

/// Drives the rider-side ride lifecycle. Driver matching and movement are
/// simulated with timers until a real backend is connected.
class RiderController extends ChangeNotifier {
  static const _historyKey = 'rider_history';

  final _rand = Random();
  Timer? _timer;
  SharedPreferences? _prefs;

  Ride? ride;
  LatLng? driverLocation;
  final List<Ride> history = [];

  void load(SharedPreferences prefs) {
    _prefs = prefs;
    history.clear();
    try {
      history.addAll((prefs.getStringList(_historyKey) ?? [])
          .map((s) => Ride.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    } on Object {
      history.clear();
    }
  }

  void reset() {
    _timer?.cancel();
    ride = null;
    driverLocation = null;
    history.clear();
    notifyListeners();
  }

  void bookRide({required Place pickup, required Place drop, required VehicleType vehicle}) {
    _timer?.cancel();
    ride = Ride(
      id: 'NR${DateTime.now().millisecondsSinceEpoch}',
      pickup: pickup,
      drop: drop,
      vehicle: vehicle,
      otp: (1000 + _rand.nextInt(9000)).toString(),
    );
    driverLocation = null;
    notifyListeners();
    _timer = Timer(const Duration(seconds: 3), _assignDriver);
  }

  void _assignDriver() {
    final current = ride;
    if (current == null) return;
    current
      ..driver = MockData.drivers[current.vehicle.index]
      ..status = RideStatus.driverAssigned;
    final start = LatLng(current.pickup.point.latitude + 0.012, current.pickup.point.longitude - 0.01);
    _moveDriver(start, current.pickup.point, () {
      current.status = RideStatus.driverArrived;
      notifyListeners();
      _timer = Timer(const Duration(seconds: 5), _startTrip);
    });
  }

  void _startTrip() {
    final current = ride;
    if (current == null) return;
    current.status = RideStatus.inProgress;
    _moveDriver(current.pickup.point, current.drop.point, () {
      current.status = RideStatus.completed;
      notifyListeners();
    }, steps: 15);
  }

  void _moveDriver(LatLng from, LatLng to, VoidCallback onArrive, {int steps = 10}) {
    var step = 0;
    driverLocation = from;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      step++;
      final f = step / steps;
      driverLocation = LatLng(
        from.latitude + (to.latitude - from.latitude) * f,
        from.longitude + (to.longitude - from.longitude) * f,
      );
      notifyListeners();
      if (step >= steps) {
        t.cancel();
        onArrive();
      }
    });
  }

  void cancelRide() {
    _timer?.cancel();
    ride = null;
    driverLocation = null;
    notifyListeners();
  }

  void finishRide() {
    if (ride != null) {
      history.insert(0, ride!);
      _prefs?.setStringList(_historyKey, history.map((r) => jsonEncode(r.toJson())).toList());
    }
    cancelRide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
