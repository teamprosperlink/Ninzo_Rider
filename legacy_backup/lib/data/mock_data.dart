import 'package:latlong2/latlong.dart';

import '../models/ride.dart';

/// Placeholder data used until the app is connected to a backend.
class MockData {
  static const currentLocation =
      Place('Current location', 'Janpath, New Delhi', LatLng(28.6139, 77.2090));

  static const places = [
    Place('Connaught Place', 'Rajiv Chowk, New Delhi', LatLng(28.6315, 77.2167)),
    Place('India Gate', 'Kartavya Path, New Delhi', LatLng(28.6129, 77.2295)),
    Place('Karol Bagh', 'Ajmal Khan Road, New Delhi', LatLng(28.6519, 77.1909)),
    Place('Saket', 'Select Citywalk, Saket', LatLng(28.5245, 77.2066)),
    Place('Lajpat Nagar', 'Central Market, Lajpat Nagar', LatLng(28.5677, 77.2433)),
    Place('New Delhi Railway Station', 'Paharganj, New Delhi', LatLng(28.6430, 77.2194)),
    Place('Hauz Khas Village', 'Hauz Khas, New Delhi', LatLng(28.5535, 77.1940)),
    Place('Chandni Chowk', 'Old Delhi', LatLng(28.6506, 77.2303)),
  ];

  static const drivers = [
    DriverInfo(name: 'Ramesh Kumar', vehicleModel: 'Honda Activa', vehicleNumber: 'DL 3S AB 1234', rating: 4.8),
    DriverInfo(name: 'Suresh Yadav', vehicleModel: 'Bajaj RE Auto', vehicleNumber: 'DL 1R CD 5678', rating: 4.6),
    DriverInfo(name: 'Mohit Singh', vehicleModel: 'Maruti Dzire', vehicleNumber: 'DL 8C EF 9012', rating: 4.9),
  ];

  static const riderNames = ['Aman', 'Priya', 'Rahul', 'Sneha', 'Vikram'];
}
