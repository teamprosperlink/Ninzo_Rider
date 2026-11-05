import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Shown until the device location is known.
const defaultMapCenter = LatLng(28.6139, 77.2090); // New Delhi

/// OpenStreetMap-based map (no API key needed). Follows [center] when it
/// changes.
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.center,
    this.markers = const [],
    this.layers = const [],
    this.zoom = 14,
    this.attributionInset = 0,
  });

  final LatLng center;
  final List<Marker> markers;

  /// Drawn under the markers: a route, a radius.
  final List<Widget> layers;
  final double zoom;

  /// Lifts a compact attribution above whatever covers the map's bottom edge.
  final double attributionInset;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(MapView old) {
    super.didUpdateWidget(old);
    if (_ready && (old.center != widget.center || old.zoom != widget.zoom)) {
      _controller.move(widget.center, widget.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(initialCenter: widget.center, initialZoom: widget.zoom, onMapReady: () => _ready = true),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.prosperlink.ninzo_rider',
        ),
        ...widget.layers,
        MarkerLayer(markers: widget.markers),
          // Above whatever covers the map, small enough to leave its markers
          // readable.
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.attributionInset),
              child: const ColoredBox(
                color: Color(0xB3FFFFFF),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: Color(0xFF0C0C0C))),
                ),
              ),
            ),
          ),
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

Marker riderMarker(LatLng point, IconData icon) {
  return Marker(
    point: point,
    width: 40,
    height: 40,
    child: Container(
      decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 22),
    ),
  );
}
