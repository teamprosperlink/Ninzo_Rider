import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap-based map (no API key needed). Swap for Google Maps later
/// if required.
class MapView extends StatelessWidget {
  const MapView({super.key, required this.center, this.markers = const [], this.zoom = 14});

  final LatLng center;
  final List<Marker> markers;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: zoom),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.prosperlink.ninzo_rider',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

Marker mapPin(LatLng point, IconData icon, Color color) {
  return Marker(
    point: point,
    width: 44,
    height: 44,
    alignment: Alignment.topCenter,
    child: Icon(icon, color: color, size: 40),
  );
}

Marker vehicleMarker(LatLng point, IconData icon) {
  return Marker(
    point: point,
    width: 40,
    height: 40,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.black87,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}
