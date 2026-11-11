import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_endpoints.dart';

Future<void> callPhone(String phone) => launchUrl(Uri(scheme: ApiEndpoints.telScheme, path: phone));

/// Opens turn-by-turn directions in Google Maps (or the browser).
Future<void> openDirections(LatLng to) => launchUrl(
  Uri.https(ApiEndpoints.directionsHost, ApiEndpoints.directionsPath, {ApiEndpoints.directionsApiParam: ApiEndpoints.directionsApiVersion, ApiEndpoints.directionsDestinationParam: '${to.latitude},${to.longitude}'}),
  mode: LaunchMode.externalApplication,
);
