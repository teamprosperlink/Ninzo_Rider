import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:ninzo_rider/data/datasources/remote/google_api.dart';
import 'package:ninzo_rider/data/repositories/google_route_repository.dart';

String _encode(List<LatLng> points) {
  final out = StringBuffer();
  void write(int value) {
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }

  var lat = 0, lng = 0;
  for (final p in points) {
    final a = (p.latitude * 1e5).round(), b = (p.longitude * 1e5).round();
    write(a - lat);
    write(b - lng);
    lat = a;
    lng = b;
  }
  return out.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('ninzo/device'),
      (call) async => {'key': 'k', 'package': 'p', 'sha1': 's'},
    );
  });

  const start = LatLng(13.1000, 77.6000);
  const corner = LatLng(13.1000, 77.6100);
  const end = LatLng(13.1100, 77.6100);

  (GoogleRouteRepository, List<int>) repository() {
    final calls = <int>[0];
    final client = MockClient((request) async {
      calls[0]++;
      return http.Response(
        jsonEncode({
          'routes': [
            {
              'legs': [
                {
                  'steps': [
                    {
                      'polyline': {'encodedPolyline': _encode([start, corner])},
                      'navigationInstruction': {'maneuver': 'DEPART', 'instructions': 'Head east on Main Rd'},
                    },
                    {
                      'polyline': {'encodedPolyline': _encode([corner, end])},
                      'navigationInstruction': {'maneuver': 'TURN_LEFT', 'instructions': 'Turn left onto Service Rd\nPass the mall'},
                    },
                  ],
                },
              ],
            },
          ],
        }),
        200,
      );
    });
    return (GoogleRouteRepository(GoogleApi(), client: client), calls);
  }

  test('Gives the next real turn, the road left and the distance', () async {
    final (routes, _) = repository();
    final step = await routes.nextStep(start, end);
    expect(step.maneuver, 'Turn left');
    expect(step.street, 'Onto Service Rd');
    expect(step.instruction, startsWith('In 1.1 km, turn left'));
    expect(step.totalKm, closeTo(2.2, 0.1));
    expect(step.path.last.latitude, closeTo(end.latitude, 0.0001));
  });

  test('Follows the same route without asking Google again', () async {
    final (routes, calls) = repository();
    await routes.nextStep(start, end);
    final later = await routes.nextStep(const LatLng(13.1000, 77.6050), end);
    expect(calls.first, 1);
    expect(later.totalKm, closeTo(1.65, 0.1));
  });

  test('Past the last turn it says arrive', () async {
    final (routes, _) = repository();
    await routes.nextStep(start, end);
    final last = await routes.nextStep(const LatLng(13.1050, 77.6100), end);
    expect(last.maneuver, 'Arrive');
  });

  test('Asks again for a new destination', () async {
    final (routes, calls) = repository();
    await routes.nextStep(start, end);
    await routes.nextStep(start, corner);
    expect(calls.first, 2);
  });

  test('Without Google it falls back to the straight line', () async {
    final routes = GoogleRouteRepository(GoogleApi(), client: MockClient((_) async => http.Response('', 403)));
    final step = await routes.nextStep(start, end);
    expect(step.instruction, isEmpty);
    expect(step.path, isEmpty);
    expect(step.totalKm, greaterThan(1));
  });
}
