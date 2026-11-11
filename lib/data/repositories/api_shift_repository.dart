import 'package:latlong2/latlong.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/online_status.dart' show ScooterStock;
import '../../domain/entities/shift.dart';
import '../../domain/repositories/shift_end_repositories.dart';
import '../../domain/repositories/shift_repository.dart';
import '../datasources/remote/rider_api_client.dart';
import '../datasources/remote/rider_api_session.dart';

/// The rider's day on the rider API.
///
/// The API has no shift schedule, morning stock request or hub packing: the
/// rider rides to their assigned node, the shift starts there
/// (`POST /riders/me/shifts/start` takes the scooter waiting at the node) and
/// they scan lots onto it. So the stock request always reads "ready", the trip
/// to the "hub" is the trip to the node, and arriving there starts the shift
/// and goes straight to scanning. The phase is kept on the phone; an open
/// shift on the server moves it on to scanning at least.
class ApiShiftRepository implements ShiftRepository {
  ApiShiftRepository(this._session);

  final RiderApiSession _session;

  /// The API has no end time; the shift runs this long unless time is added.
  static const defaultLength = Duration(hours: 8);

  @override
  Stream<Shift?> watchToday(String uid) => _session.watch(_shift);

  Shift? _shift() {
    final node = _session.assignedNode;
    if (node == null) return null;
    final day = _session.day;
    final open = _session.openShift;
    final now = _session.clock();
    final started = RiderApiSession.parseTime(open?['started_at']);
    final refillHub = day['refillHub'] as String?;
    var phase = ShiftPhase.values.asNameMap()[day['phase']] ?? ShiftPhase.notStarted;
    if (open != null && refillHub == null && phase.isBefore(ShiftPhase.scanning)) phase = ShiftPhase.scanning;
    final spot = day['spot'] as Map<String, dynamic>?;
    final lots = _session.lots;
    // At the end the server takes the lots back; what was left is kept.
    final left = (phase == ShiftPhase.ended ? (day['returned'] as num?)?.toInt() : null) ??
        lots.fold<int>(0, (sum, lot) => sum + ((lot['qty'] as num?)?.toInt() ?? 0));
    return Shift(
      id: _session.indiaDate,
      start: started ?? DateTime(now.year, now.month, now.day),
      end: (started ?? now).add(defaultLength),
      hub: _refillHub(refillHub) ?? Hub(id: node.id, name: node.name, area: '', point: node.point),
      spot: spot == null
          ? Spot(name: node.name, point: node.point)
          : Spot(
              name: spot['name'] as String? ?? '',
              point: LatLng((spot['lat'] as num).toDouble(), (spot['lng'] as num).toDouble()),
            ),
      scooter: _scooter(open),
      hubDistanceKm: node.hubDistanceM == null ? null : node.hubDistanceM! / 1000,
      stockRequest: StockRequestStatus.ready,
      phase: phase,
      stock: StockLoad(
        items: {for (final lot in lots) lot['item_id']}.length,
        // What was loaded: what's left plus what was sold.
        portions: left + _session.delivered.values.fold(0, (sum, d) => sum + ((d['qty'] as num?)?.toInt() ?? 0)),
        scanned: (day['scanned'] as num?)?.toInt() ?? 0,
      ),
      refill: refillHub == null ? null : RefillLoad(hubName: refillHub),
      refillRound: (day['refillRound'] as num?)?.toInt() ?? 0,
    );
  }

  /// On a refill, the hub of the restock request or suggestion named [name],
  /// where the hub trip goes; null without one, or from a server that sends
  /// no hub location.
  Hub? _refillHub(String? name) {
    if (name == null) return null;
    final hubs = [
      _session.restockRequest?['hub'],
      for (final s in _session.suggestions) s['hub'],
    ].whereType<Map<String, dynamic>>();
    final hub = hubs.where((h) => h['name'] == name && h['lat'] is num && h['lng'] is num).firstOrNull;
    if (hub == null) return null;
    return Hub(
      id: hub['id'] as String? ?? '',
      name: name,
      area: '',
      point: LatLng((hub['lat'] as num).toDouble(), (hub['lng'] as num).toDouble()),
    );
  }

  /// The open shift's scooter: its plate and battery (null until scooter data exists).
  static Scooter _scooter(Map<String, dynamic>? open) {
    final scooter = open?['scooter'] as Map<String, dynamic>?;
    return Scooter(
      plate: scooter?['plate'] as String? ?? '',
      batteryPercent: (scooter?['battery_pct'] as num?)?.toInt(),
    );
  }

  /// No morning stock request in the API.
  @override
  Future<void> replyToStockRequest(String uid, String shiftId, StockRequestStatus reply) async {}

  @override
  Future<void> setPhase(String uid, String shiftId, ShiftPhase phase) async {
    var next = phase;
    // The API allows another shift the same day: starting again after an
    // ended one begins a fresh day on the phone.
    if (phase == ShiftPhase.checklist && _session.day['phase'] == ShiftPhase.ended.name) {
      await _session.setDay({
        'scanned': 0,
        'spot': null,
        'refillHub': null,
        'refillRound': 0,
        for (final key in RiderApiSession.shiftKeys) key: null,
      });
    }
    // At the node: the shift starts there, and there's nothing to wait for.
    if (phase == ShiftPhase.atHub && _session.day['refillHub'] == null) {
      await _startShift();
      next = ShiftPhase.scanning;
    }
    if (phase == ShiftPhase.ended) await _endShift();
    await _session.setDay({'phase': next.name});
  }

  Future<void> _startShift() async {
    final node = _session.assignedNode;
    if (node == null) throw const AppException('no_node');
    try {
      await _session.api.startShift({'node_id': node.id});
    } on RiderApiException catch (e) {
      // rider_not_approved, rider_not_verified, shift_limit_reached,
      // no_scooter_at_node: no frame says why, the screen stays.
      if (e.code != 'shift_already_open') throw AppException(e.code);
    }
    await _session.refresh();
  }

  Future<void> _endShift() async {
    // "Returned to hub" (Shift 50): the server empties the scooter at the end.
    await _session.setDay({'returned': _session.lots.fold(0, (sum, lot) => sum + ((lot['qty'] as num?)?.toInt() ?? 0))});
    try {
      await _session.api.endShift();
    } on RiderApiException catch (e) {
      if (e.code == 'order_in_progress') throw const AppException(AppErrorReasons.orderInProgress);
      if (e.code != 'no_open_shift') throw AppException(e.code);
    }
    _session.stopPings();
    await _session.setDay({'endedAt': _session.clock().toUtc().toIso8601String()});
    await _session.refresh();
  }

  /// Off to the hub for a refill. "Request hub to prepare" with no request
  /// open asks the hub for what was sold (`POST /restock`); a confirmed
  /// suggestion is already the request.
  @override
  Future<void> setRefill(
    String uid,
    String shiftId, {
    required RefillLoad? refill,
    required int round,
    required ShiftPhase phase,
  }) async {
    if (refill != null && phase == ShiftPhase.atHub && !_restockOpen()) await _askHub(refill.hubName);
    await _session.setDay({'refillHub': refill?.hubName, 'refillRound': round, 'phase': phase.name});
  }

  static const _restockDone = {'received', 'closed', 'expired', 'cancelled'};

  bool _restockOpen() {
    final request = _session.restockRequest;
    if (request != null && !_restockDone.contains(request['state'])) return true;
    // A confirm waiting on the phone becomes the request once it's sent.
    final queued = _session.dayList('queuedRestocks');
    return _session.suggestions.any((s) => queued.contains(s['id']));
  }

  Future<void> _askHub(String hubName) async {
    final hubId = _session.hubIds[hubName] ?? _session.hubIds.values.firstOrNull;
    final items = _session.soldByItem();
    if (items.isEmpty) {
      // Nothing sold yet: the item running lowest.
      final lowest = [..._session.lots]
        ..sort((a, b) => ((a['qty'] as num?) ?? 0).compareTo((b['qty'] as num?) ?? 0));
      final item = lowest.firstOrNull?['item_id'] as String?;
      if (item != null) items[item] = ScooterStock.lowStockAt;
    }
    if (hubId == null || items.isEmpty) return;
    try {
      await _session.api.createRestock({
        'hub_id': hubId,
        'items': [
          for (final MapEntry(:key, :value) in items.entries) {'item_id': key, 'qty': value},
        ],
      });
    } on RiderApiException catch (e) {
      // One open request per scooter: it's already on its way.
      if (e.code != 'restock_already_open') throw AppException(e.code);
    }
    await _session.refresh(full: true);
  }

  @override
  Future<void> setSpot(String uid, String shiftId, Spot spot) => _session.setDay({
    'spot': {'name': spot.name, 'lat': spot.point.latitude, 'lng': spot.point.longitude},
  });

  @override
  Future<void> recordScans(String uid, String shiftId, int scanned) => _session.setDay({'scanned': scanned});
}

/// Only verified riders can start a shift (`GET /riders/me/verification`).
/// The API has no "open on another phone".
class ApiShiftSessionRepository implements ShiftSessionRepository {
  ApiShiftSessionRepository(this._session);

  final RiderApiSession _session;

  @override
  Future<bool> openElsewhere(String uid, String shiftId) async => false;

  @override
  Future<void> claim(String uid, String shiftId) async {
    final String? status;
    try {
      status = (await _session.api.getVerification())['status'] as String?;
    } on RiderApiException catch (e) {
      // Staging has no verification endpoint yet (404); starting the shift
      // still refuses an unverified rider with rider_not_verified.
      if (e.status == 404) return;
      throw AppException(e.code);
    }
    if (status == 'verified') return;
    // Failed or expired: the documents go again (`POST
    // /riders/me/verification/start`, by hand until DigiLocker is approved).
    if (status == 'failed' || status == 'expired') {
      try {
        _session.verificationNext = await _session.api.startVerification({'method': 'manual_upload'});
      } on RiderApiException catch (e) {
        throw AppException(e.code);
      }
    }
    // No frame says why, the screen stays.
    throw AppException('verification_$status');
  }

  @override
  Future<void> markEnded(String uid, String shiftId) async {}
}
