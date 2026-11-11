import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_durations.dart';
import '../../core/errors/app_exception.dart';
import '../../core/api/api_endpoints.dart';
import '../../domain/entities/rider_area.dart';
import '../../domain/repositories/place_repository.dart';
import '../datasources/remote/google_api.dart';

/// Google Places (New) for search and details, Google Geocoding for "here".
/// The key is the one the map uses: it comes from the app's own manifest.
class GooglePlaceRepository implements PlaceRepository {
  GooglePlaceRepository(this._api, {http.Client? client}) : _client = client ?? http.Client();

  static const _region = 'in';
  static const _language = 'en';

  final GoogleApi _api;
  final http.Client _client;
  String? _session;
  int _latestSearch = 0;

  /// Keystrokes and the pick that follows share a token, so Google bills them
  /// as one search.
  String get _token => _session ??= List.generate(32, (_) => Random.secure().nextInt(16).toRadixString(16)).join();

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode != 200) throw const AppException();
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<List<RiderArea>> search(String query) async {
    // Waits for a pause in typing; each request costs money.
    final mine = ++_latestSearch;
    await Future<void>.delayed(AppDurations.placeSearchPause);
    if (mine != _latestSearch) return const [];
    final response = await _client.post(
      Uri.parse(ApiEndpoints.placesAutocomplete),
      headers: {...await _api.headers(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': query,
        'includedRegionCodes': [_region],
        'languageCode': _language,
        'sessionToken': _token,
      }),
    );
    final suggestions = _decode(response)['suggestions'] as List<dynamic>? ?? const [];
    return [
      for (final suggestion in suggestions)
        if ((suggestion as Map<String, dynamic>)['placePrediction'] case final Map<String, dynamic> place)
          RiderArea(
            id: place['placeId'] as String,
            name: _text(place, 'mainText'),
            city: _text(place, 'secondaryText'),
          ),
    ];
  }

  String _text(Map<String, dynamic> place, String part) {
    final format = place['structuredFormat'] as Map<String, dynamic>?;
    final text = format?[part] as Map<String, dynamic>?;
    return text?['text'] as String? ?? '';
  }

  @override
  Future<RiderArea> details(RiderArea area) async {
    final session = _session;
    _session = null;
    final response = await _client.get(
      Uri.parse(ApiEndpoints.placeDetails(area.id)).replace(queryParameters: {'sessionToken': ?session}),
      headers: {...await _api.headers(), 'X-Goog-FieldMask': 'location'},
    );
    final location = _decode(response)['location'] as Map<String, dynamic>?;
    return RiderArea(
      id: area.id,
      name: area.name,
      city: area.city,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  Future<RiderArea?> near(LatLng point) async {
    final response = await _client.get(
      Uri.parse(ApiEndpoints.geocode).replace(
        queryParameters: {
          'latlng': '${point.latitude},${point.longitude}',
          'result_type': 'sublocality|locality',
          'language': _language,
          'key': await _api.key(),
        },
      ),
    );
    final results = _decode(response)['results'] as List<dynamic>? ?? const [];
    if (results.isEmpty) return null;
    final first = results.first as Map<String, dynamic>;
    final parts = (first['address_components'] as List<dynamic>).cast<Map<String, dynamic>>();
    final location = (first['geometry'] as Map<String, dynamic>)['location'] as Map<String, dynamic>;
    final name = parts.first['long_name'] as String;
    final address = first['formatted_address'] as String? ?? '';
    return RiderArea(
      id: first['place_id'] as String,
      name: name,
      city: address.startsWith('$name, ') ? address.substring(name.length + 2) : address,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
    );
  }
}
