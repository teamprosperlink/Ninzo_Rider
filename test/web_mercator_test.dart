import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ninzo_rider/core/utils/web_mercator.dart';

void main() {
  test('The equator and the prime meridian are the middle of the world', () {
    final middle = worldPixel(const LatLng(0, 0), 1);
    expect(middle.dx, 256);
    expect(middle.dy, closeTo(256, 0.000001));
  });

  test('A place comes back from its pixel', () {
    const place = LatLng(13.1007, 77.5963);
    final back = pointAtWorldPixel(worldPixel(place, 16.5), 16.5);
    expect(back.latitude, closeTo(place.latitude, 0.000001));
    expect(back.longitude, closeTo(place.longitude, 0.000001));
  });

  test('One zoom level doubles the distance on screen', () {
    const a = LatLng(13.1, 77.5);
    const b = LatLng(13.2, 77.6);
    final at14 = worldPixel(b, 14) - worldPixel(a, 14);
    final at15 = worldPixel(b, 15) - worldPixel(a, 15);
    expect(at15.distance, closeTo(at14.distance * 2, 0.0001));
  });
}
