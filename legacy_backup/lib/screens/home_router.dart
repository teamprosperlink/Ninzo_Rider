import 'package:flutter/material.dart';

import '../models/ride.dart';
import '../services/app_session.dart';
import 'driver/driver_home_screen.dart';
import 'driver/driver_registration_screen.dart';
import 'rider/rider_home_screen.dart';

/// Home screen for the given mode. Driver mode needs a registered
/// driver profile first.
Widget homeScreenFor(AppMode mode) => switch (mode) {
      AppMode.rider => const RiderHomeScreen(),
      AppMode.driver =>
        AppSession.driverProfile == null ? const DriverRegistrationScreen() : const DriverHomeScreen(),
    };
