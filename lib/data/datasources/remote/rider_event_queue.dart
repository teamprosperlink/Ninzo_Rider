import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'rider_api.dart';
import 'rider_api_client.dart';

/// Where queued events wait on the phone.
abstract interface class RiderEventStore {
  Future<List<Map<String, dynamic>>> load();
  Future<void> save(List<Map<String, dynamic>> events);
}

class PrefsRiderEventStore implements RiderEventStore {
  const PrefsRiderEventStore();

  static const _key = 'riderApi.events';

  @override
  Future<List<Map<String, dynamic>>> load() async {
    final text = (await SharedPreferences.getInstance()).getString(_key);
    if (text == null) return [];
    final json = jsonDecode(text);
    return json is List ? [...json.cast<Map<String, dynamic>>()] : [];
  }

  @override
  Future<void> save(List<Map<String, dynamic>> events) async =>
      (await SharedPreferences.getInstance()).setString(_key, jsonEncode(events));
}

/// The rider API's offline events (`POST /riders/me/events`): an action whose
/// direct call can't get through is kept on the phone and sent, in order,
/// once there's signal. The event's id is the direct call's Idempotency-Key,
/// so the two count once.
class RiderEventQueue {
  RiderEventQueue(this._api, {RiderEventStore? store, DateTime Function()? clock})
    : _store = store ?? const PrefsRiderEventStore(),
      _clock = clock ?? DateTime.now;

  final RiderApi _api;
  final RiderEventStore _store;
  final DateTime Function() _clock;
  Future<void> _last = Future.value();
  bool _hasEvents = true;

  /// Location fixes kept at most; older ones are worth nothing.
  static const maxLocations = 100;

  /// No way through right now (as opposed to a refusal).
  static bool isOffline(RiderApiException e) => e.code == 'network' || (e.retryable && (e.status ?? 0) >= 500);

  /// `^[A-Za-z0-9_-]{8,128}$`, as the contract asks.
  static String newEventId(String type) =>
      '${type.replaceAll('_', '-')}-${List.generate(24, (_) => Random.secure().nextInt(16).toRadixString(16)).join()}';

  /// An event of [type] with a new id, stamped now.
  Map<String, dynamic> event(String type, Map<String, dynamic> payload, {String? id, DateTime? at}) => {
    'event_id': id ?? newEventId(type),
    'type': type,
    'device_time': (at ?? _clock()).toUtc().toIso8601String(),
    'payload': payload,
  };

  /// Sends [direct] with the event's id as its key; without a way through, the
  /// event is queued and this returns null.
  Future<T?> sendOrQueue<T>(Map<String, dynamic> event, Future<T> Function(String key) direct) async {
    try {
      return await direct(event['event_id'] as String);
    } on RiderApiException catch (e) {
      if (!isOffline(e)) rethrow;
      await add(event);
      return null;
    }
  }

  Future<void> add(Map<String, dynamic> event) => _serial(() async {
    var events = [...await _store.load(), event];
    final locations = events.where((e) => e['type'] == 'location').toList();
    if (locations.length > maxLocations) {
      final drop = locations.take(locations.length - maxLocations).toSet();
      events = events.where((e) => !drop.contains(e)).toList();
    }
    await _store.save(events);
    _hasEvents = true;
  });

  Future<List<Map<String, dynamic>>> pending() => _store.load();

  /// Sends what's queued, oldest first. Accepted and refused-for-good events
  /// go; a retryable refusal, or no way through, waits for the next time.
  Future<void> flush() => _serial(() async {
    if (!_hasEvents) return;
    final events = await _store.load();
    if (events.isEmpty) {
      _hasEvents = false;
      return;
    }
    final Map<String, dynamic> result;
    try {
      result = await _api.sendEventBatch(events);
    } on RiderApiException {
      return;
    }
    final retry = {
      for (final r in (result['rejected'] as List? ?? const []).cast<Map<String, dynamic>>())
        if (r['retryable'] == true) r['id'],
    };
    // Queued meanwhile: kept too.
    final now = await _store.load();
    final sent = {for (final e in events) e['event_id']};
    await _store.save([
      for (final e in now)
        if (!sent.contains(e['event_id']) || retry.contains(e['event_id'])) e,
    ]);
  });

  Future<void> _serial(Future<void> Function() action) => _last = _last.then((_) => action()).catchError((Object _) {});
}
