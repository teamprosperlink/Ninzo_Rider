import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart' show LatLng;

import '../constants/app_numbers.dart';
import '../constants/app_sizes.dart';
import '../utils/web_mercator.dart';

/// A widget pinned to a place on the map, centred on it.
class MapMarker {
  const MapMarker({required this.point, required this.width, required this.height, required this.child});

  final LatLng point;
  final double width;
  final double height;
  final Widget child;
}

/// A line through places on the map.
class MapLine {
  const MapLine({required this.points, required this.color, required this.width});

  final List<LatLng> points;
  final Color color;
  final double width;
}

/// Google Maps with the design's markers and route drawn over it. Follows
/// [center] when it changes; [center] stays in the middle of the widget.
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.center,
    this.markers = const [],
    this.underMarkers = const [],
    this.lines = const [],
    this.zoom = AppSizes.s14,
  });

  /// Widget tests have no native map to host.
  @visibleForTesting
  static bool showBaseMap = true;

  final LatLng center;
  final List<MapMarker> markers;

  /// Drawn under [lines], which are drawn under [markers].
  final List<MapMarker> underMarkers;
  final List<MapLine> lines;
  final double zoom;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  google.GoogleMapController? _controller;
  late LatLng _target = _targetFor(widget);
  late double _zoom = widget.zoom;

  /// The native map runs past the bottom edge, so its middle is that much
  /// south of [MapView.center].
  LatLng _targetFor(MapView map) {
    final middle = worldPixel(map.center, map.zoom);
    return pointAtWorldPixel(middle.translate(AppSizes.s0, AppMapConfig.belowEdge / 2), map.zoom);
  }

  @override
  void didUpdateWidget(MapView old) {
    super.didUpdateWidget(old);
    if (old.center != widget.center || old.zoom != widget.zoom) {
      _target = _targetFor(widget);
      _zoom = widget.zoom;
      _controller?.moveCamera(
        google.CameraUpdate.newLatLngZoom(google.LatLng(_target.latitude, _target.longitude), _zoom),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _follow(google.CameraPosition camera) => setState(() {
    _target = LatLng(camera.target.latitude, camera.target.longitude);
    _zoom = camera.zoom;
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final origin = worldPixel(_target, _zoom) - Offset(size.width / 2, (size.height + AppMapConfig.belowEdge) / 2);
        Offset onScreen(LatLng point) => worldPixel(point, _zoom) - origin;

        Widget pinned(MapMarker marker) {
          final at = onScreen(marker.point);
          return Positioned(
            left: at.dx - marker.width / 2,
            top: at.dy - marker.height / 2,
            width: marker.width,
            height: marker.height,
            child: marker.child,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            if (MapView.showBaseMap)
              ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Runs past the bottom edge, which cuts off Google's logo.
                    Positioned(
                      left: AppSizes.s0,
                      top: AppSizes.s0,
                      right: AppSizes.s0,
                      bottom: -AppMapConfig.belowEdge,
                      child: google.GoogleMap(
                        initialCameraPosition: google.CameraPosition(
                          target: google.LatLng(_target.latitude, _target.longitude),
                          zoom: _zoom,
                        ),
                        onMapCreated: (controller) => _controller = controller,
                        onCameraMove: _follow,
                        // The overlay has no rotation or tilt; nothing the design doesn't draw.
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        compassEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                    ),
                  ],
                ),
              ),
            IgnorePointer(
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    ...widget.underMarkers.map(pinned),
                    for (final line in widget.lines)
                      CustomPaint(painter: _LinePainter(line.points.map(onScreen).toList(), line.color, line.width)),
                    ...widget.markers.map(pinned),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter(this.points, this.color, this.width);

  final List<Offset> points;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.points != points || old.color != color || old.width != width;
}
