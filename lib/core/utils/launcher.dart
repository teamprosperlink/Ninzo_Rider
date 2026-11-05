import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> callPhone(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

/// Opens turn-by-turn directions in Google Maps (or the browser).
Future<void> openDirections(LatLng to) => launchUrl(
  Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '${to.latitude},${to.longitude}'}),
  mode: LaunchMode.externalApplication,
);
