import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// One account can use the app in either mode and switch any time.
enum AppMode { rider, driver }

enum VehicleType {
  bike('Bike', Icons.two_wheeler, 20, 7),
  auto('Auto', Icons.electric_rickshaw, 30, 11),
  car('Car', Icons.local_taxi, 50, 15);

  const VehicleType(this.label, this.icon, this.baseFare, this.perKm);

  final String label;
  final IconData icon;
  final double baseFare;
  final double perKm;

  double fareFor(double km) => (baseFare + perKm * km).roundToDouble();
}

enum RideStatus { searching, driverAssigned, driverArrived, inProgress, completed }

class Place {
  const Place(this.name, this.address, this.point);

  final String name;
  final String address;
  final LatLng point;

  Map<String, dynamic> toJson() =>
      {'name': name, 'address': address, 'lat': point.latitude, 'lng': point.longitude};

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        j['name'] as String,
        j['address'] as String,
        LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
      );
}

class DriverInfo {
  const DriverInfo({
    required this.name,
    required this.vehicleModel,
    required this.vehicleNumber,
    required this.rating,
  });

  final String name;
  final String vehicleModel;
  final String vehicleNumber;
  final double rating;

  Map<String, dynamic> toJson() =>
      {'name': name, 'vehicleModel': vehicleModel, 'vehicleNumber': vehicleNumber, 'rating': rating};

  factory DriverInfo.fromJson(Map<String, dynamic> j) => DriverInfo(
        name: j['name'] as String,
        vehicleModel: j['vehicleModel'] as String,
        vehicleNumber: j['vehicleNumber'] as String,
        rating: (j['rating'] as num).toDouble(),
      );
}

/// Details a user must register once before using Driver mode.
class DriverProfile {
  const DriverProfile({
    required this.name,
    required this.vehicleType,
    required this.vehicleModel,
    required this.vehicleNumber,
    required this.licenceNumber,
  });

  final String name;
  final VehicleType vehicleType;
  final String vehicleModel;
  final String vehicleNumber;
  final String licenceNumber;

  Map<String, dynamic> toJson() => {
        'name': name,
        'vehicleType': vehicleType.name,
        'vehicleModel': vehicleModel,
        'vehicleNumber': vehicleNumber,
        'licenceNumber': licenceNumber,
      };

  factory DriverProfile.fromJson(Map<String, dynamic> j) => DriverProfile(
        name: j['name'] as String,
        vehicleType: VehicleType.values.byName(j['vehicleType'] as String),
        vehicleModel: j['vehicleModel'] as String,
        vehicleNumber: j['vehicleNumber'] as String,
        licenceNumber: j['licenceNumber'] as String,
      );
}

class Ride {
  Ride({
    required this.id,
    required this.pickup,
    required this.drop,
    required this.vehicle,
    required this.otp,
    this.riderName = 'You',
    this.status = RideStatus.searching,
    this.driver,
  }) : distanceKm = kmBetween(pickup.point, drop.point);

  final String id;
  final Place pickup;
  final Place drop;
  final VehicleType vehicle;
  final String otp;
  final String riderName;
  final double distanceKm;
  RideStatus status;
  DriverInfo? driver;

  double get fare => vehicle.fareFor(distanceKm);

  /// Rough city ETA assuming ~25 km/h average speed.
  int get etaMinutes => (distanceKm / 25 * 60).ceil();

  static double kmBetween(LatLng a, LatLng b) => const Distance()(a, b) / 1000;

  Map<String, dynamic> toJson() => {
        'id': id,
        'pickup': pickup.toJson(),
        'drop': drop.toJson(),
        'vehicle': vehicle.name,
        'otp': otp,
        'riderName': riderName,
        'status': status.name,
        if (driver != null) 'driver': driver!.toJson(),
      };

  factory Ride.fromJson(Map<String, dynamic> j) => Ride(
        id: j['id'] as String,
        pickup: Place.fromJson(j['pickup'] as Map<String, dynamic>),
        drop: Place.fromJson(j['drop'] as Map<String, dynamic>),
        vehicle: VehicleType.values.byName(j['vehicle'] as String),
        otp: j['otp'] as String,
        riderName: j['riderName'] as String,
        status: RideStatus.values.byName(j['status'] as String),
        driver: j['driver'] == null ? null : DriverInfo.fromJson(j['driver'] as Map<String, dynamic>),
      );
}

String rupees(double amount) => '₹${amount.toStringAsFixed(0)}';
