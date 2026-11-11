import 'package:latlong2/latlong.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/online_status.dart';
import '../../domain/entities/restock.dart';
import '../../domain/entities/shift.dart';
import '../../domain/repositories/online_repository.dart';
import '../../domain/usecases/spot_usecases.dart';
import '../datasources/remote/rider_api_client.dart';
import '../datasources/remote/rider_api_session.dart';

/// "A2931" for an order: the API has no order number, so the end of the
/// offer's id stands in for it.
String apiOrderNumber(String id) {
  // "off_mock01" gives MOCK01; a UUID gives its last six characters.
  final part = id.split(RegExp('[_-]')).last;
  return (part.length > 6 ? part.substring(part.length - 6) : part).toUpperCase();
}

/// The online rider on the rider API: open offers are the queue (Shift 28,
/// "Start order" accepts the first), the earnings are the day's, the
/// relocation suggestion is the nudge and the restock request or suggestion
/// is the restock. Breaks, added time and the Online clock stay on the
/// phone: the API has nothing for them.
class ApiOnlineRepository implements OnlineRepository {
  ApiOnlineRepository(this._session);

  final RiderApiSession _session;

  static const _activeRestock = {'confirmed', 'hub_accepted', 'packing', 'ready', 'partial'};

  @override
  Stream<OnlineStatus> watch(String uid, String shiftId) => _session.watch(_status);

  OnlineStatus _status() {
    final day = _session.day;
    final money = _session.earnings;
    final breakState = day['break'] as Map<String, dynamic>?;
    final left = <String, int>{};
    for (final lot in _session.lots) {
      final item = lot['item_id'] as String;
      left[item] = (left[item] ?? 0) + ((lot['qty'] as num?)?.toInt() ?? 0);
    }
    final delivered = _session.delivered.values;
    final times = [for (final d in delivered) ?(d['seconds'] as num?)?.toInt()];
    return OnlineStatus(
      onlineAt: RiderApiSession.parseTime(day['onlineAt']),
      orders: (money?['orders'] as num?)?.toInt() ?? 0,
      earned: rupeesOf(money?['total']),
      shiftEnd: RiderApiSession.parseTime(day['shiftEnd']),
      queue: [
        for (final offer in _session.offers)
          if (offer['id'] != day['activeOfferId']) _assigned(offer),
      ],
      activeOrderId: _session.activeOrderId,
      itemsLeft: [for (final MapEntry(:key, :value) in left.entries) ItemLeft(name: _session.itemName(key), left: value)],
      breakState: breakState == null
          ? null
          : BreakState(
              startedAt: DateTime.parse(breakState['startedAt'] as String),
              length: Duration(seconds: (breakState['seconds'] as num).toInt()),
            ),
      nudge: _nudge(),
      restock: _restock(),
      earnings: money == null ? null : _breakdown(money),
      sold: delivered.fold(0, (sum, d) => sum + ((d['qty'] as num?)?.toInt() ?? 0)),
      averageDeliverySeconds: times.isEmpty ? null : times.reduce((a, b) => a + b) ~/ times.length,
      // After a restart the server may no longer send the ended shift.
      endedAt:
          RiderApiSession.parseTime((_session.state?['shift'] as Map<String, dynamic>?)?['ended_at']) ??
          RiderApiSession.parseTime(day['endedAt']),
    );
  }

  /// Money is `amount_minor` in paise.
  static double rupeesOf(Object? money) =>
      money is Map<String, dynamic> ? ((money['amount_minor'] as num?) ?? 0) / 100 : 0;

  EarningsBreakdown _breakdown(Map<String, dynamic> money) => EarningsBreakdown(
    orderPay: [
      for (final order in (money['order_earnings'] as List? ?? const []).cast<Map<String, dynamic>>())
        rupeesOf(order['amount']),
    ].fold(0.0, (sum, r) => sum + r),
    incentives: rupeesOf(money['incentives']),
    repositionMinutes: ((money['repositioning_seconds'] as num?)?.toInt() ?? 0) ~/ 60,
    repositionPay: rupeesOf(money['repositioning']),
  );

  AssignedOrder _assigned(Map<String, dynamic> offer) {
    final gate = offer['gate'] as Map<String, dynamic>? ?? const {};
    final lines = (offer['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    return AssignedOrder(
      id: offer['id'] as String,
      number: apiOrderNumber(offer['id'] as String),
      gate: gate['label'] as String? ?? '',
      items: lines.fold(0, (sum, line) => sum + ((line['qty'] as num?)?.toInt() ?? 0)),
      place: gate['entry_notes'] as String?,
    );
  }

  RelocationNudge? _nudge() {
    final move = _session.relocation;
    final id = move?['id'] as String?;
    if (move == null || id == null || _session.dayList('dismissedRelocations').contains(id)) return null;
    final node = _session.nodeById(move['node_id'] as String?);
    if (node == null) return null;
    final accepted = _session.day['acceptedRelocation'] as Map<String, dynamic>?;
    if (accepted?['id'] != id && !(RiderApiSession.parseTime(move['expires_at'])?.isAfter(_session.clock()) ?? true)) {
      return null;
    }
    final from = _session.assignedNode?.point ?? node.point;
    final meters = SpotRules.metersBetween(from, node.point);
    final nudge = RelocationNudge(
      spot: Spot(name: node.name, point: node.point),
      // "3 orders expected, nobody nearby": the API has only the reason.
      ordersWaiting: int.tryParse((move['reason'] as String? ?? '').split(' ').first) ?? 0,
      meters: meters.round(),
      rideMinutes: SpotRules.rideMinutes(meters),
    );
    final at = RiderApiSession.parseTime(accepted?['at']);
    return accepted?['id'] == id && at != null ? nudge.accepted(at) : nudge;
  }

  /// The confirmed request if there is one, else the newest suggestion.
  RestockRequest? _restock() {
    final dismissed = _session.dayList('dismissedRestocks');
    final request = _session.restockRequest;
    if (request != null && _activeRestock.contains(request['state']) && !dismissed.contains(request['id'])) {
      return _fromRequest(request);
    }
    final suggestion = _openSuggestion();
    if (suggestion == null) return null;
    return RestockRequest(
      stage: RestockStage.suggested,
      hubName: (suggestion['hub'] as Map<String, dynamic>?)?['name'] as String? ?? '',
      lines: _lines(suggestion),
      expiresAt: RiderApiSession.parseTime(suggestion['expires_at']),
    );
  }

  /// A suggestion the rider hasn't answered (a confirm waiting on the phone
  /// counts as answered).
  Map<String, dynamic>? _openSuggestion() {
    final answered = {..._session.dayList('dismissedRestocks'), ..._session.dayList('queuedRestocks')};
    return _session.suggestions.where((s) => !answered.contains(s['id'])).firstOrNull;
  }

  List<RestockLine> _lines(Map<String, dynamic> json) => [
    for (final line in (json['items'] as List? ?? const []).cast<Map<String, dynamic>>())
      RestockLine(
        itemId: line['item_id'] as String,
        name: line['name'] as String? ?? _session.itemName(line['item_id'] as String),
        quantity: (line['qty'] as num?)?.toInt() ?? 0,
      ),
  ];

  RestockRequest _fromRequest(Map<String, dynamic> request) {
    final hub = (request['hub'] as Map<String, dynamic>?)?['name'] as String? ?? '';
    final shortfall = request['shortfall'] as Map<String, dynamic>?;
    final items = (request['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    RestockShortage? shortage;
    if (request['state'] == 'partial' && shortfall != null) {
      final short = items.where((i) => ((i['filled_qty'] as num?) ?? 0) < ((i['qty'] as num?) ?? 0)).firstOrNull;
      shortage = RestockShortage(
        itemName: short?['name'] as String? ?? '',
        asked: (short?['qty'] as num?)?.toInt() ?? 0,
        canGive: (short?['filled_qty'] as num?)?.toInt() ?? 0,
        otherHubName: (shortfall['other_hub'] as Map<String, dynamic>?)?['name'] as String? ?? hub,
        otherHubKm: 0,
        otherHubHas: 0,
      );
    }
    return RestockRequest(
      stage: shortage == null ? RestockStage.inProgress : RestockStage.hubShort,
      hubName: hub,
      lines: _lines(request),
      arriveBy: RiderApiSession.parseTime(request['arrive_by']),
      readyAt: RiderApiSession.parseTime(request['slot_at']),
      packing: switch (request['state']) {
        'hub_accepted' => HubPacking.accepted,
        'packing' => HubPacking.packing,
        'ready' => HubPacking.ready,
        _ => HubPacking.sent,
      },
      shortage: shortage,
    );
  }

  @override
  Future<void> markOnline(String uid, String shiftId) =>
      _session.setDay({'onlineAt': _session.clock().toUtc().toIso8601String()});

  @override
  Future<void> setShiftEnd(String uid, String shiftId, DateTime end) =>
      _session.setDay({'shiftEnd': end.toUtc().toIso8601String()});

  /// "Start order" accepts the offer (`POST /offers/{id}/accept`).
  @override
  Future<void> startOrder(String uid, String shiftId, AssignedOrder order) async {
    final offer = _session.offers.where((o) => o['id'] == order.id).firstOrNull;
    if (offer == null) throw const AppException('offer_gone');
    final Map<String, dynamic> json;
    try {
      json = await _session.api.acceptOffer(order.id, {'fencing_token': offer['fencing_token']});
    } on RiderApiException catch (e) {
      // offer_expired, offer_taken, stale_fencing_token: it leaves the queue.
      await _session.refresh();
      throw AppException(e.code);
    }
    final accepted = json['order'] as Map<String, dynamic>;
    _session.noteOrder(accepted);
    await _session.setDay({'activeOrderId': accepted['id'], 'activeOfferId': order.id});
  }

  @override
  Future<void> setBreak(String uid, String shiftId, BreakState? state) => _session.setDay({
    'break': state == null
        ? null
        : {'startedAt': state.startedAt.toUtc().toIso8601String(), 'seconds': state.length.inSeconds},
  });

  /// Taking the nudge accepts the relocation; anything else hides it here.
  @override
  Future<void> setNudge(String uid, String shiftId, RelocationNudge? nudge) async {
    final id = _session.relocation?['id'] as String?;
    if (id == null) return;
    if (nudge?.stage == NudgeStage.accepted) {
      try {
        await _session.api.acceptRelocation(id);
      } on RiderApiException catch (e) {
        throw AppException(e.code);
      }
      await _session.setDay({
        'acceptedRelocation': {'id': id, 'at': (nudge!.acceptedAt ?? _session.clock()).toUtc().toIso8601String()},
      });
    } else if (nudge == null) {
      await _session.addToDayList('dismissedRelocations', id);
    }
  }

  /// Confirm, decline and the shortfall answer of Restock 01–05.
  @override
  Future<void> setRestock(String uid, String shiftId, RestockRequest? restock) async {
    final shown = _restock();
    if (shown == null) return;
    final request = _session.restockRequest;
    final suggestion = shown.stage == RestockStage.suggested ? _openSuggestion() : null;
    final id = (suggestion ?? request)?['id'] as String?;
    if (id == null) return;
    final events = _session.events;
    try {
      if (restock == null) {
        // The API can't cancel a confirmed request; it's only hidden here.
        if (suggestion != null) {
          const body = {'reason': 'not_now'};
          await events.sendOrQueue(
            events.event('restock_decline', {'request_id': id, ...body}),
            (key) => _session.api.declineRestock(id, body, idempotencyKey: key),
          );
        }
        await _session.addToDayList('dismissedRestocks', id);
      } else if (suggestion != null && restock.stage == RestockStage.inProgress) {
        final body = {
          'quantity_override': [
            for (final line in restock.lines) {'item_id': line.itemId, 'qty': line.quantity},
          ],
        };
        final sent = await events.sendOrQueue(
          events.event('restock_confirm', {'request_id': id, ...body}),
          (key) => _session.api.confirmRestock(id, body, idempotencyKey: key),
        );
        // Waiting on the phone: the suggestion is answered.
        if (sent == null) await _session.addToDayList('queuedRestocks', id);
      } else if (shown.stage == RestockStage.hubShort && restock.stage == RestockStage.inProgress) {
        // "Try Hub 4" moves to the other hub; "Take 2" keeps what was packed.
        final toOtherHub = restock.hubName != shown.hubName;
        final otherHubOffered = (request?['shortfall'] as Map<String, dynamic>?)?['action'] == 'other_hub';
        await _session.api.respondToShortfall(id, {'accept': toOtherHub == otherHubOffered});
      }
    } on RiderApiException catch (e) {
      throw AppException(e.code);
    }
    await _session.refresh(full: true);
  }

  /// The stock is the server's: what a refill loads shows in `GET /riders/me/stock`.
  @override
  Future<void> addStock(String uid, String shiftId, int portions) async {}

  /// The order's last screen is done with; "Start next order" accepts the next.
  @override
  Future<void> finishOrder(String uid, String shiftId, String orderId, {String? thenStart}) async {
    await _session.addToDayList('finishedOrders', orderId);
    await _session.setDay({'activeOrderId': null, 'activeOfferId': null});
    if (thenStart == null) return;
    final next = _status().queue.where((o) => o.id == thenStart).firstOrNull;
    if (next != null) await startOrder(uid, shiftId, next);
  }
}

/// Where a rider is, for distances in the API repositories.
LatLng? apiSpotPoint(RiderApiSession session) {
  final spot = session.day['spot'] as Map<String, dynamic>?;
  if (spot != null) return LatLng((spot['lat'] as num).toDouble(), (spot['lng'] as num).toDouble());
  return session.assignedNode?.point;
}
