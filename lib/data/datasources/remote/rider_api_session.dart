import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/rider_settings.dart';
import '../../models/rider_settings_model.dart';
import 'rider_api.dart';
import 'rider_api_client.dart';
import 'rider_api_stream.dart';
import 'rider_event_queue.dart';

/// A node: where scooters wait and where the rider waits for offers.
class ApiNode {
  const ApiNode({required this.id, required this.name, required this.point, this.hubDistanceM});

  factory ApiNode.fromJson(Map<String, dynamic> json) => ApiNode(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    point: LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()),
    hubDistanceM: (json['hub_distance_m'] as num?)?.toInt(),
  );

  final String id;
  final String name;
  final LatLng point;

  /// Straight-line metres to the zone's nearest active hub; null without one.
  final int? hubDistanceM;
}

/// One GPS fix, as the location ping sends it.
class RiderFix {
  const RiderFix({required this.point, this.speedMps = 0, this.accuracyM = 0, required this.at});

  final LatLng point;
  final double speedMps;
  final double accuracyM;
  final DateTime at;
}

/// The phone's GPS, with speed and accuracy.
abstract interface class RiderFixSource {
  Stream<RiderFix> fixes();
}

/// Doesn't ask for permission (the app's screens do); without it, no fixes.
class GeolocatorFixSource implements RiderFixSource {
  const GeolocatorFixSource();

  static const _settings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);

  @override
  Stream<RiderFix> fixes() async* {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    yield* Geolocator.getPositionStream(locationSettings: _settings).map(
      (p) => RiderFix(
        point: LatLng(p.latitude, p.longitude),
        speedMps: p.speed < 0 ? 0 : p.speed,
        accuracyM: p.accuracy,
        at: p.timestamp,
      ),
    );
  }
}

/// What the phone keeps of the rider's day (phase, choices the API has no
/// field for), so it survives a restart.
abstract interface class RiderDayStore {
  Future<Map<String, dynamic>> load(String key);
  Future<void> save(String key, Map<String, dynamic> day);
}

class PrefsRiderDayStore implements RiderDayStore {
  const PrefsRiderDayStore();

  @override
  Future<Map<String, dynamic>> load(String key) async {
    final text = (await SharedPreferences.getInstance()).getString(key);
    if (text == null) return {};
    final json = jsonDecode(text);
    return json is Map<String, dynamic> ? json : {};
  }

  @override
  Future<void> save(String key, Map<String, dynamic> day) async =>
      (await SharedPreferences.getInstance()).setString(key, jsonEncode(day));
}

/// The rider API's live picture of the rider, shared by the API repositories.
///
/// `GET /riders/me/state` is the authority: it's polled every [pollEvery]
/// while anything watches. The slower facts (nodes, stock, earnings, restock
/// suggestions) come every [slowEvery] polls and whenever the state's `seq`
/// moves. The live stream (`/riders/me/stream`) brings a change at once:
/// an offer is fetched with `GET /riders/me/offers`, anything else with a
/// poll. While a shift is open the phone's GPS goes to
/// `POST /riders/me/location` at the rate the server asks for.
class RiderApiSession {
  RiderApiSession(
    this.api, {
    RiderDayStore? store,
    RiderFixSource? fixes,
    RiderEventStore? eventStore,
    Stream<bool>? signal,
    DateTime Function()? clock,
    this.pollEvery = const Duration(seconds: 5),
    this.slowEvery = 6,
    Stream<Map<String, dynamic>> Function()? liveStream,
    this.liveRetryEvery = const Duration(seconds: 5),
  }) : _liveStream = liveStream ?? (() => riderLiveStream(api.client)),
       _store = store ?? const PrefsRiderDayStore(),
       _fixes = fixes ?? const GeolocatorFixSource(),
       clock = clock ?? DateTime.now {
    events = RiderEventQueue(api, store: eventStore, clock: this.clock);
    // Signal back: what waited on the phone goes now.
    _signalSub = signal?.listen((online) {
      if (online) unawaited(events.flush());
    });
  }

  final RiderApi api;

  /// Actions that couldn't get through, sent with `POST /riders/me/events`.
  late final RiderEventQueue events;
  StreamSubscription<bool>? _signalSub;
  final RiderDayStore _store;
  final RiderFixSource _fixes;
  final DateTime Function() clock;
  final Duration pollEvery;
  final int slowEvery;
  final Stream<Map<String, dynamic>> Function() _liveStream;

  /// How soon a closed live stream is opened again.
  final Duration liveRetryEvery;

  static const defaultPingSeconds = 5;

  /// India's day: the earnings day.
  static const _indiaOffset = Duration(hours: 5, minutes: 30);

  final _changes = StreamController<void>.broadcast();

  // ── What the server says ──
  Map<String, dynamic>? rider;
  List<ApiNode> nodes = const [];
  String? assignedNodeId;
  Map<String, dynamic>? relocation;
  Map<String, dynamic>? state;
  List<Map<String, dynamic>> lots = const [];
  Map<String, dynamic>? earnings;
  List<Map<String, dynamic>> suggestions = const [];

  /// `GET /riders/me/offers` since the last state: an offer the stream
  /// announced before the next poll.
  List<Map<String, dynamic>> listedOffers = const [];

  /// `GET /restock/{id}`: the open request with its queue slot and the hub's
  /// progress.
  Map<String, dynamic>? restockDetail;

  /// `GET /riders/me/verification`: pending, verified, failed or expired;
  /// null when the server has none (staging: 404).
  String? verification;

  /// `GET /riders/me/notifications`: what the server told this rider, newest
  /// first (Profile 05).
  List<Map<String, dynamic>> notifications = const [];

  /// `GET /riders/me/shift-plan`: today's planned shift, the morning stock
  /// request and the hub's packing; null on a day with none.
  Map<String, dynamic>? shiftPlan;

  /// `GET /riders/me/shifts`: the last 7 days' shifts, newest first, with
  /// their times and what was delivered.
  List<Map<String, dynamic>> shiftHistory = const [];

  /// `GET /riders/me/documents`: the document photos uploaded.
  List<Map<String, dynamic>> documents = const [];

  /// Where verification goes next (`upload_url`, `redirect_url`), once a
  /// failed or expired one was started again.
  Map<String, dynamic>? verificationNext;
  final itemNames = <String, String>{};
  final hubIds = <String, String>{};

  /// The zone's hubs from `GET /restock/options`, with `manager_phone`.
  List<Map<String, dynamic>> hubs = const [];

  /// Orders this rider has had, by id, as last seen.
  final orders = <String, Map<String, dynamic>>{};

  /// When the ride started (Ready accepted, or first seen packed).
  final rideStartedAt = <String, DateTime>{};

  /// When the order was first seen ARRIVED.
  final arrivedAt = <String, DateTime>{};

  /// The masked number for "Call customer".
  final customerPhones = <String, String>{};
  final _phoneAsked = <String>{};

  // ── What this phone keeps for the day ──
  Map<String, dynamic> day = {};
  String? _dayKey;

  bool _loaded = false;
  Future<void>? _loading;
  int _listeners = 0;
  int _tick = 0;
  Timer? _timer;
  StreamSubscription<RiderFix>? _fixSub;
  RiderFix? _lastFix;
  Timer? _pingTimer;
  bool _refreshing = false;
  StreamSubscription<Map<String, dynamic>>? _liveSub;
  Timer? _liveRetry;
  bool _disposed = false;

  // ── Reading ──

  /// The open shift, or null.
  Map<String, dynamic>? get openShift {
    final shift = state?['shift'];
    if (shift is! Map<String, dynamic> || shift['ended_at'] != null) return null;
    return shift;
  }

  ApiNode? nodeById(String? id) => nodes.where((n) => n.id == id).firstOrNull;

  /// The node of the open shift, the one the server assigns, or, when it
  /// assigns none (staging does), the first node of the rider's zone.
  ApiNode? get assignedNode =>
      nodeById(openShift?['node_id'] as String?) ?? nodeById(assignedNodeId) ?? nodes.firstOrNull;

  /// Open offers the rider hasn't answered, soonest to expire first.
  List<Map<String, dynamic>> get offers {
    final now = clock();
    final declined = {...dayList('declinedOffers')};
    final fromState = (state?['offers'] as List? ?? const []).cast<Map<String, dynamic>>();
    final known = {for (final offer in fromState) offer['id']};
    final list = [
      for (final offer in [...fromState, ...listedOffers.where((o) => !known.contains(o['id']))])
        if (offer['state'] == 'open' &&
            !declined.contains(offer['id']) &&
            (parseTime(offer['expires_at'])?.isAfter(now) ?? true))
          offer,
    ];
    list.sort((a, b) => (a['expires_at'] as String? ?? '').compareTo(b['expires_at'] as String? ?? ''));
    return list;
  }

  /// The restock request in the state, with what `GET /restock/{id}` added.
  Map<String, dynamic>? get restockRequest {
    final request = state?['restock_request'] as Map<String, dynamic>?;
    final detail = restockDetail;
    if (request == null) return null;
    return detail != null && detail['id'] == request['id'] ? {...request, ...detail} : request;
  }

  Map<String, dynamic>? get currentOrder => state?['current_order'] as Map<String, dynamic>?;

  /// The order the rider is on, until they leave its last screen.
  String? get activeOrderId => day['activeOrderId'] as String?;

  List<String> dayList(String key) => [...(day[key] as List? ?? const []).cast<String>()];

  String itemName(String itemId) => itemNames[itemId] ?? itemId;

  /// "yyyy-MM-dd" in India.
  String get indiaDate {
    final d = clock().toUtc().add(_indiaOffset);
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static DateTime? parseTime(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;

  // ── Watching ──

  Stream<void> get changes => _changes.stream;

  /// [read] now and after every change, polling while listened to.
  Stream<T> watch<T>(T Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<T>(
      onListen: () {
        _retain();
        sub = changes.listen((_) => controller.add(read()));
        ensureLoaded().then(
          (_) => controller.isClosed ? null : controller.add(read()),
          onError: (Object e) => controller.isClosed ? null : controller.addError(e),
        );
      },
      onCancel: () {
        sub?.cancel();
        _release();
      },
    );
    return controller.stream;
  }

  void _retain() {
    _listeners++;
    _timer ??= Timer.periodic(pollEvery, (_) => refresh());
    _startLive();
  }

  void _release() {
    _listeners--;
    if (_listeners > 0) return;
    _timer?.cancel();
    _timer = null;
    _stopLive();
  }

  // ── The live stream ──

  void _startLive() {
    if (_liveSub != null || _listeners <= 0 || _disposed) return;
    _liveRetry?.cancel();
    _liveSub = _liveStream().listen(
      _onLive,
      onError: (Object _) {},
      onDone: () {
        _liveSub = null;
        if (_listeners > 0 && !_disposed) _liveRetry = Timer(liveRetryEvery, _startLive);
      },
    );
  }

  void _stopLive() {
    _liveRetry?.cancel();
    _liveRetry = null;
    unawaited(_liveSub?.cancel());
    _liveSub = null;
  }

  void _onLive(Map<String, dynamic> message) {
    // Messages carry {type, data, server_time}; seq may sit in either.
    final seq = message['seq'] ?? (message['data'] as Map<String, dynamic>?)?['seq'];
    switch (message['type']) {
      case 'auth_ok':
        return;
      case 'offer':
        unawaited(refreshOffers());
      case 'heartbeat' when seq != null && seq == state?['seq']:
        return;
      default:
        unawaited(refresh());
    }
  }

  /// `GET /riders/me/offers`: the offers now, before the next state poll.
  Future<void> refreshOffers() async {
    try {
      listedOffers = [...((await api.listOffers())['offers'] as List? ?? const []).cast<Map<String, dynamic>>()];
      if (_changed()) notify();
    } on RiderApiException {
      // The next poll brings it.
    }
  }

  void notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// The first full load; a failure is tried again on the next call.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= () async {
      try {
        await refresh(full: true, rethrowErrors: true);
        _loaded = true;
      } finally {
        _loading = null;
      }
    }();
  }

  /// One poll. Errors keep the last picture (unless [rethrowErrors]).
  Future<void> refresh({bool full = false, bool rethrowErrors = false}) async {
    if (_refreshing && !rethrowErrors) return;
    _refreshing = true;
    try {
      await _loadDay();
      final slow = full || _tick % slowEvery == 0;
      _tick++;
      rider ??= (await api.getRider())['rider'] as Map<String, dynamic>?;
      final fresh = await api.getRiderState();
      // The server can be reached: anything queued goes first.
      await events.flush();
      final moved = fresh['seq'] != state?['seq'];
      state = fresh;
      // The state is the authority: what was listed before it is in it now.
      listedOffers = const [];
      final current = currentOrder;
      if (current != null) noteOrder(current);
      if (slow) await _refreshSlow();
      if (slow || moved) await refreshStock();
      if (slow || moved || _feeMissing()) await _refreshEarnings();
      if (slow || moved) await _refreshRestock();
      if (slow || moved) await _refreshPlanAndNotifications();
      await _followActiveOrder();
      _updatePings();
      // A poll that brings nothing new doesn't rebuild anything.
      if (_changed()) notify();
    } catch (_) {
      if (rethrowErrors) rethrow;
    } finally {
      _refreshing = false;
    }
  }

  String? _lastPicture;

  bool _changed() {
    Object? withoutTime(Map<String, dynamic>? json) => json == null ? null : ({...json}..remove('server_time'));
    final picture = jsonEncode([
      withoutTime(state),
      lots,
      withoutTime(earnings),
      [for (final n in nodes) n.id],
      assignedNodeId,
      relocation,
      suggestions,
      orders,
      customerPhones,
      [...rideStartedAt.keys, ...arrivedAt.keys],
      [for (final o in offers) o['id']],
      restockDetail,
      shiftPlan,
      notifications,
      shiftHistory,
      help,
      documents,
      hubs,
      rider,
      day,
    ]);
    if (picture == _lastPicture) return false;
    _lastPicture = picture;
    return true;
  }

  /// `GET /riders/me/help`: the help centre's questions and answers.
  List<Map<String, dynamic>> help = const [];

  Future<void> _refreshSlow() async {
    // What the app works by, the zone's own (`GET /riders/me/settings`).
    try {
      final json = (await api.getSettings())['settings'] as Map<String, dynamic>?;
      if (json != null) RiderSettings.current = riderSettingsFromJson(json, fallback: RiderSettings.current);
    } on RiderApiException {
      // Keeps the last.
    }
    try {
      help = [...((await api.getHelp())['faq'] as List? ?? const []).cast<Map<String, dynamic>>()];
    } on RiderApiException {
      // Keeps the last.
    }
    final zone = rider?['zone_id'] as String?;
    try {
      final json = await api.listNodes(zoneId: zone);
      nodes = [for (final n in (json['nodes'] as List? ?? const []).cast<Map<String, dynamic>>()) ApiNode.fromJson(n)];
      assignedNodeId = json['assigned_node_id'] as String?;
      relocation = json['relocation'] as Map<String, dynamic>?;
    } on RiderApiException {
      // Keeps the last nodes.
    }
    if (openShift != null) {
      try {
        suggestions = [
          ...((await api.listRestockSuggestions())['suggestions'] as List? ?? const []).cast<Map<String, dynamic>>(),
        ];
      } on RiderApiException {
        // Keeps the last ones.
      }
    }
    if (hubIds.isEmpty) {
      try {
        final options = await api.getRestockOptions();
        for (final item in (options['items'] as List? ?? const []).cast<Map<String, dynamic>>()) {
          itemNames[item['item_id'] as String] = item['name'] as String? ?? '';
        }
        hubs = [...(options['hubs'] as List? ?? const []).cast<Map<String, dynamic>>()];
        for (final hub in hubs) {
          hubIds[hub['name'] as String? ?? ''] = hub['id'] as String;
        }
      } on RiderApiException {
        // Names fall back on the item ids.
      }
    }
  }

  // ── Today's plan, and what the server told the rider (Profile 05) ──

  Future<void> _refreshPlanAndNotifications() async {
    try {
      shiftPlan = (await api.getShiftPlan())['plan'] as Map<String, dynamic>?;
    } on RiderApiException {
      // Keeps the last.
    }
    try {
      notifications = [
        ...((await api.listNotifications())['notifications'] as List? ?? const []).cast<Map<String, dynamic>>(),
      ];
    } on RiderApiException {
      // Keeps the last.
    }
    try {
      shiftHistory = [
        ...((await api.listShifts(days: historyDays))['shifts'] as List? ?? const []).cast<Map<String, dynamic>>(),
      ];
    } on RiderApiException {
      // Keeps the last.
    }
    try {
      documents = [...((await api.listDocuments())['documents'] as List? ?? const []).cast<Map<String, dynamic>>()];
    } on RiderApiException {
      // Keeps the last.
    }
  }

  /// `GET /riders/me/documents` now, after an upload.
  Future<void> refreshDocuments() async {
    try {
      documents = [...((await api.listDocuments())['documents'] as List? ?? const []).cast<Map<String, dynamic>>()];
      notify();
    } on RiderApiException {
      // The next poll brings it.
    }
  }

  /// How many days of shifts My shifts shows.
  static const historyDays = 7;

  /// The shift [shiftId] as `GET /riders/me/shifts` last listed it.
  Map<String, dynamic>? shiftRecord(String? shiftId) => shiftHistory.where((s) => s['id'] == shiftId).firstOrNull;

  /// One of the shift calls (online, break, planned end): its reply is the shift now.
  Future<void> changeShift(Future<Map<String, dynamic>> Function() call) async {
    final shift = (await call())['shift'] as Map<String, dynamic>?;
    if (shift != null) state = {...?state, 'shift': shift};
    notify();
  }

  /// `POST /riders/me/shift-plan/reply`: coming or not_today.
  Future<void> replyToShiftPlan(String reply) async {
    shiftPlan = (await api.replyToShiftPlan(reply))['plan'] as Map<String, dynamic>?;
    notify();
  }

  /// `PATCH /riders/me`: the rider's own details; the reply is the rider now.
  Future<void> updateRider(Map<String, dynamic> changes) async {
    rider = (await api.updateRider(changes))['rider'] as Map<String, dynamic>?;
    notify();
  }

  /// The zone's hub named [name], or its first.
  Map<String, dynamic>? hubNamed(String? name) => hubs.where((h) => h['name'] == name).firstOrNull ?? hubs.firstOrNull;

  // ── Kept on the phone ──

  /// What the phone keeps under [key] (registration details the API has no field for).
  Future<Map<String, dynamic>> readKept(String key) => _store.load(key);

  Future<void> writeKept(String key, Map<String, dynamic> value) async {
    await _store.save(key, value);
    notify();
  }


  /// "yyyy-MM-dd" in India, [daysAgo] days back.
  String indiaDateAgo(int daysAgo) => indiaDateOf(clock().subtract(Duration(days: daysAgo)));

  /// "yyyy-MM-dd" of [at] in India.
  String indiaDateOf(DateTime at) {
    final d = at.toUtc().add(_indiaOffset);
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  /// `GET /riders/me/verification`, once; a 404 leaves it null.
  Future<void> loadVerification() async {
    try {
      verification = (await api.getVerification())['status'] as String?;
    } on RiderApiException {
      verification = null;
    }
  }

  /// `GET /restock/{id}` for the open request.
  Future<void> _refreshRestock() async {
    final id = (state?['restock_request'] as Map<String, dynamic>?)?['id'] as String?;
    if (id == null) {
      restockDetail = null;
      return;
    }
    try {
      restockDetail = (await api.getRestock(id))['request'] as Map<String, dynamic>?;
    } on RiderApiException {
      // Keeps the last.
    }
  }

  /// `GET /riders/me/stock`: the lots on the scooter.
  Future<void> refreshStock() async {
    lots = [...((await api.getStock())['lots'] as List? ?? const []).cast<Map<String, dynamic>>()];
  }

  /// The order just handed over isn't in the earnings yet: the server
  /// credits it a moment after the handover.
  bool _feeMissing() {
    final id = activeOrderId;
    if (id == null || !const {'HANDED_OVER', 'COMPLETED'}.contains(orders[id]?['state'])) return false;
    final paid = (earnings?['order_earnings'] as List? ?? const []).cast<Map<String, dynamic>>();
    return !paid.any((e) => e['order_id'] == id);
  }

  Future<void> _refreshEarnings() async {
    try {
      earnings = await api.getEarnings(date: indiaDate);
    } on RiderApiException {
      // Keeps the last.
    }
  }

  /// The active order's own record when the state no longer carries it (it
  /// was handed over, cancelled or reassigned); an order the server still
  /// has on the rider after a restart becomes active again.
  Future<void> _followActiveOrder() async {
    final active = activeOrderId;
    final current = currentOrder;
    if (active == null && current != null && !dayList('finishedOrders').contains(current['id'])) {
      await setDay({'activeOrderId': current['id']});
      return;
    }
    if (active != null && current?['id'] != active) await fetchOrder(active);
  }

  Future<Map<String, dynamic>?> fetchOrder(String orderId) async {
    try {
      final order = (await api.getOrder(orderId))['order'] as Map<String, dynamic>;
      noteOrder(order);
      return order;
    } on RiderApiException {
      return orders[orderId];
    }
  }

  /// Keeps [order] and stamps when it started riding and arrived.
  void noteOrder(Map<String, dynamic> order) {
    final id = order['id'] as String;
    orders[id] = order;
    for (final line in (order['items'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      itemNames.putIfAbsent(line['item_id'] as String, () => line['name'] as String? ?? '');
    }
    final now = clock();
    final orderState = order['state'] as String?;
    if (const {'PACKED', 'TIMER_RUNNING', 'ARRIVED'}.contains(orderState)) stampRide(id, now);
    if (orderState == 'ARRIVED' && !arrivedAt.containsKey(id)) {
      arrivedAt[id] = now;
      unawaited(_keepStamp(_arrivedKey, id, now));
    }
    if (const {'HANDED_OVER', 'COMPLETED'}.contains(orderState)) unawaited(_keepDelivered(order));
    if (const {'PACKED', 'TIMER_RUNNING', 'ARRIVED'}.contains(orderState) && _phoneAsked.add(id)) {
      unawaited(_askPhone(id));
    }
  }

  /// `POST /orders/{id}/call` once the ride starts; the number is masked.
  Future<void> _askPhone(String orderId) async {
    try {
      final phone = (await api.startMaskedCall(orderId))['phone'] as String?;
      if (phone != null) {
        customerPhones[orderId] = phone;
        notify();
      }
    } on RiderApiException {
      _phoneAsked.remove(orderId);
    }
  }

  // ── When each order rode and arrived, kept for the day ──

  static const _rideKey = 'rideStarted';
  static const _arrivedKey = 'arrived';

  /// Day keys that belong to one shift; a new shift the same day clears them.
  static const shiftKeys = [_rideKey, _arrivedKey, 'delivered', 'returned', 'endedAt'];

  /// When the ride started: the saved time wins, so it survives a restart.
  DateTime? rideStartOf(String orderId) => _savedStamp(_rideKey, orderId) ?? rideStartedAt[orderId];

  /// When the rider arrived at the gate, saved like [rideStartOf].
  DateTime? arrivalOf(String orderId) => _savedStamp(_arrivedKey, orderId) ?? arrivedAt[orderId];

  /// Marks the ride as started at [at] unless it already was.
  void stampRide(String orderId, DateTime at) {
    if (rideStartedAt.containsKey(orderId)) return;
    rideStartedAt[orderId] = at;
    unawaited(_keepStamp(_rideKey, orderId, at));
  }

  DateTime? _savedStamp(String key, String orderId) => parseTime((day[key] as Map?)?[orderId]);

  Future<void> _keepStamp(String key, String orderId, DateTime at) async {
    await _loadDay();
    final saved = {...(day[key] as Map? ?? const {})};
    if (saved.containsKey(orderId)) return;
    saved[orderId] = at.toUtc().toIso8601String();
    await setDay({key: saved});
  }

  /// Delivered orders this shift: items sold and seconds from ride to gate,
  /// for the shift summary.
  Map<String, Map<String, dynamic>> get delivered => {
    for (final MapEntry(:key, :value) in (day['delivered'] as Map? ?? const {}).entries)
      key as String: (value as Map).cast<String, dynamic>(),
  };

  /// What was sold this shift, by item id.
  Map<String, int> soldByItem() {
    final sold = <String, int>{};
    for (final order in delivered.values) {
      for (final MapEntry(:key, :value) in (order['items'] as Map? ?? const {}).entries) {
        sold[key as String] = (sold[key] ?? 0) + ((value as num?)?.toInt() ?? 0);
      }
    }
    return sold;
  }

  Future<void> _keepDelivered(Map<String, dynamic> order) async {
    await _loadDay();
    final id = order['id'] as String;
    final saved = {...(day['delivered'] as Map? ?? const {})};
    if (saved.containsKey(id)) return;
    final lines = (order['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final start = rideStartOf(id);
    final end = arrivalOf(id) ?? parseTime(order['handed_over_at']) ?? clock();
    saved[id] = {
      'qty': lines.fold(0, (sum, line) => sum + ((line['qty'] as num?)?.toInt() ?? 0)),
      'items': {
        for (final line in lines) line['item_id'] as String: (line['qty'] as num?)?.toInt() ?? 0,
      },
      if (start != null) 'seconds': end.difference(start).inSeconds.clamp(0, 1 << 31),
    };
    await setDay({'delivered': saved});
  }

  // ── The day on this phone ──

  Future<void> _loadDay() async {
    final saved = await api.client.tokens.read();
    final key = 'riderApi.day.${saved?.riderId}.$indiaDate';
    if (key == _dayKey) return;
    if (_dayKey != null && saved?.riderId != rider?['id']) _forgetRider();
    _dayKey = key;
    day = await _store.load(key);
  }

  void _forgetRider() {
    rider = null;
    state = null;
    nodes = const [];
    assignedNodeId = null;
    relocation = null;
    lots = const [];
    earnings = null;
    suggestions = const [];
    shiftPlan = null;
    notifications = const [];
    shiftHistory = const [];
    documents = const [];
    verification = null;
    orders.clear();
  }

  /// Merges [values] into the day (a null value removes it) and saves it.
  Future<void> setDay(Map<String, dynamic> values) async {
    await _loadDay();
    for (final MapEntry(:key, :value) in values.entries) {
      if (value == null) {
        day.remove(key);
      } else {
        day[key] = value;
      }
    }
    final key = _dayKey;
    if (key != null) await _store.save(key, day);
    notify();
  }

  Future<void> addToDayList(String key, String value) => setDay({
    key: {...dayList(key), value}.toList(),
  });

  // ── Location pings ──

  void _updatePings() {
    if (openShift != null) {
      _fixSub ??= _fixes.fixes().listen((fix) => _lastFix = fix, onError: (Object _) {});
      _pingTimer ??= Timer(Duration.zero, _ping);
    } else {
      stopPings();
    }
  }

  void stopPings() {
    _fixSub?.cancel();
    _fixSub = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _ping() async {
    var next = defaultPingSeconds;
    final fix = _lastFix;
    if (fix != null) {
      final now = clock();
      // No new fix for a while: the phone isn't moving.
      final stale = now.difference(fix.at) > const Duration(seconds: defaultPingSeconds * 2);
      final ping = locationPing(fix, now, stale: stale);
      try {
        final json = await api.locationPing(ping);
        next = (json['next_ping_s'] as num?)?.toInt() ?? next;
      } on RiderApiException catch (e) {
        // Without a way through it goes with the event batch later.
        if (RiderEventQueue.isOffline(e)) {
          final payload = {...ping}..remove('device_time');
          await events.add(events.event('location', payload, at: now));
        }
      }
    }
    if (_pingTimer == null) return;
    _pingTimer = Timer(Duration(seconds: next < 1 ? 1 : next), _ping);
  }

  static Map<String, dynamic> locationPing(RiderFix fix, DateTime now, {bool stale = false}) => {
    'lat': fix.point.latitude,
    'lng': fix.point.longitude,
    'speed_mps': stale ? 0 : fix.speedMps,
    'accuracy_m': fix.accuracyM,
    'device_time': now.toUtc().toIso8601String(),
  };

  void dispose() {
    _disposed = true;
    _stopLive();
    _signalSub?.cancel();
    _timer?.cancel();
    stopPings();
    _changes.close();
  }
}
