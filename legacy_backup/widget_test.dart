import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ninzo_rider/data/mock_data.dart';
import 'package:ninzo_rider/main.dart';
import 'package:ninzo_rider/models/ride.dart';
import 'package:ninzo_rider/services/app_session.dart';

Future<void> _startSession([Map<String, Object> stored = const {}]) async {
  SharedPreferences.setMockInitialValues(stored);
  await AppSession.init();
}

void main() {
  testWidgets('App opens on the login screen when logged out', (tester) async {
    await _startSession();
    await tester.pumpWidget(const NinzoRiderApp());

    expect(find.text('NinzoRider'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });

  testWidgets('Login rejects invalid phone number', (tester) async {
    await _startSession();
    await tester.pumpWidget(const NinzoRiderApp());

    await tester.enterText(find.byType(TextField), '12345');
    await tester.tap(find.text('Send OTP'));
    await tester.pump();

    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);
  });

  test('Driver mode needs registration, and the profile is remembered', () async {
    await _startSession({'phone': '9876543210'});
    expect(AppSession.isLoggedIn, isTrue);
    expect(AppSession.driverProfile, isNull);

    await AppSession.saveDriverProfile(const DriverProfile(
      name: 'Test Driver',
      vehicleType: VehicleType.auto,
      vehicleModel: 'Bajaj RE',
      vehicleNumber: 'DL 1R CD 5678',
      licenceNumber: 'DL-0420110012345',
    ));
    await AppSession.init();

    expect(AppSession.driverProfile?.name, 'Test Driver');
    expect(AppSession.driver.vehicleType, VehicleType.auto);
  });

  test('Ride history survives a restart and switching modes', () async {
    await _startSession({'phone': '9876543210'});
    final rider = AppSession.rider;
    rider.bookRide(pickup: MockData.currentLocation, drop: MockData.places.first, vehicle: VehicleType.car);
    rider.ride!.status = RideStatus.completed;
    expect(AppSession.hasActiveRide, isTrue);
    rider.finishRide();
    expect(AppSession.hasActiveRide, isFalse);

    await AppSession.setMode(AppMode.driver);
    await AppSession.setMode(AppMode.rider);
    await AppSession.init();

    expect(rider.history, hasLength(1));
    expect(rider.history.first.drop.name, MockData.places.first.name);
  });

  test('Logout clears stored data', () async {
    await _startSession({'phone': '9876543210', 'mode': 'driver'});
    await AppSession.logout();

    expect(AppSession.isLoggedIn, isFalse);
    expect(AppSession.mode, AppMode.rider);
  });
}
