import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

/// A world 256 points wide at zoom 0, the projection Google Maps draws in.
const _worldAtZoom0 = 256.0;
const _maxLatitude = 85.05112878;

double _worldSize(double zoom) => _worldAtZoom0 * math.pow(2, zoom);

/// Where [point] sits in the world, in points, at [zoom].
Offset worldPixel(LatLng point, double zoom) {
  final size = _worldSize(zoom);
  final sine = math.sin(point.latitude.clamp(-_maxLatitude, _maxLatitude) * math.pi / 180);
  return Offset(
    (point.longitude + 180) / 360 * size,
    (0.5 - math.log((1 + sine) / (1 - sine)) / (4 * math.pi)) * size,
  );
}

/// The point at [pixel] in the world, at [zoom].
LatLng pointAtWorldPixel(Offset pixel, double zoom) {
  final size = _worldSize(zoom);
  final y = 0.5 - pixel.dy / size;
  return LatLng(90 - 360 * math.atan(math.exp(-y * 2 * math.pi)) / math.pi, pixel.dx / size * 360 - 180);
}
