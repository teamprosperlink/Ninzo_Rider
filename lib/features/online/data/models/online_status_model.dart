import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:latlong2/latlong.dart';

import '../../../refill/domain/entities/restock.dart';
import '../../../shift/domain/entities/shift.dart';
import '../../domain/entities/online_status.dart';

/// Maps the online fields of `riders/{uid}/shifts/{yyyy-MM-dd}`:
///
/// ```
/// onlineAt              Timestamp (rider: first time online at the spot)
/// end                   Timestamp (rider moves it with Add time)
/// scooter.batteryPercent number (backend)
/// quietSpell            bool (backend)
/// today                 {orders, earned, orderPay, incentives, repositionMinutes,
///                       repositionPay, averageDeliverySeconds} (backend)
/// endedAt               Timestamp (rider: End shift)
/// chosenHours           number (backend: the hours the rider chose, Shift 46)
/// stock.sold            number (backend)
/// queue                 [{id, number, gate, place, items, collectCash, assignedAt}] (backend)
/// activeOrderId         string (rider: Start order; deleted on Back to your spot)
/// stock.added           number (rider: portions a finished refill added)
/// itemsLeft             [{name, left}] (backend)
/// break                 {startedAt, minutes} (rider)
/// nudge                 {spot: {name, lat, lng}, ordersWaiting, meters, rideMinutes,
///                       stage, acceptedAt} (backend offers and covers; rider accepts)
/// restock               {stage, hubName, lines: [{itemId, name, quantity}], readyInMinutes,
///                       rideMinutes, expiresAt, queueSlot, arriveBy, packing, readyAt,
///                       shortage} (backend suggests and moves it; rider answers)
/// ```
abstract final class OnlineStatusModel {
  static OnlineStatus fromFirestore(Map<String, dynamic> j) {
    final today = (j['today'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stock = (j['stock'] as Map?)?.cast<String, dynamic>() ?? const {};
    final scooter = (j['scooter'] as Map?)?.cast<String, dynamic>() ?? const {};
    final queue = (j['queue'] as List?) ?? const [];
    return OnlineStatus(
      onlineAt: (j['onlineAt'] as Timestamp?)?.toDate(),
      quiet: j['quietSpell'] as bool? ?? false,
      orders: (today['orders'] as num?)?.toInt() ?? 0,
      earned: (today['earned'] as num?)?.toDouble() ?? 0,
      sold: (stock['sold'] as num?)?.toInt() ?? 0,
      batteryPercent: (scooter['batteryPercent'] as num?)?.round(),
      shiftEnd: (j['end'] as Timestamp?)?.toDate(),
      queue: [
        for (final o in queue)
          if (o is Map) _order(o.cast<String, dynamic>()),
      ],
      activeOrderId: j['activeOrderId'] as String?,
      stockAdded: (stock['added'] as num?)?.toInt() ?? 0,
      itemsLeft: [
        for (final i in (j['itemsLeft'] as List?) ?? const [])
          if (i is Map) ItemLeft(name: i['name'] as String? ?? '', left: (i['left'] as num?)?.toInt() ?? 0),
      ],
      breakState: _break((j['break'] as Map?)?.cast<String, dynamic>()),
      nudge: _nudge((j['nudge'] as Map?)?.cast<String, dynamic>()),
      restock: _restock((j['restock'] as Map?)?.cast<String, dynamic>()),
      earnings: today['orderPay'] == null
          ? null
          : EarningsBreakdown(
              orderPay: (today['orderPay'] as num).toDouble(),
              incentives: (today['incentives'] as num?)?.toDouble() ?? 0,
              repositionMinutes: (today['repositionMinutes'] as num?)?.toInt() ?? 0,
              repositionPay: (today['repositionPay'] as num?)?.toDouble() ?? 0,
            ),
      averageDeliverySeconds: (today['averageDeliverySeconds'] as num?)?.toInt(),
      endedAt: (j['endedAt'] as Timestamp?)?.toDate(),
      chosenLength: switch (j['chosenHours']) {
        final num hours => Duration(minutes: (hours * 60).round()),
        _ => null,
      },
    );
  }

  static BreakState? _break(Map<String, dynamic>? j) {
    final started = j?['startedAt'] as Timestamp?;
    if (j == null || started == null) return null;
    return BreakState(startedAt: started.toDate(), length: Duration(minutes: (j['minutes'] as num?)?.toInt() ?? 0));
  }

  static Map<String, dynamic> breakToMap(BreakState s) => {
    'startedAt': Timestamp.fromDate(s.startedAt),
    'minutes': s.length.inMinutes,
  };

  static RelocationNudge? _nudge(Map<String, dynamic>? j) {
    final spot = (j?['spot'] as Map?)?.cast<String, dynamic>();
    if (j == null || spot == null) return null;
    return RelocationNudge(
      spot: Spot(
        name: spot['name'] as String? ?? '',
        point: LatLng((spot['lat'] as num?)?.toDouble() ?? 0, (spot['lng'] as num?)?.toDouble() ?? 0),
      ),
      ordersWaiting: (j['ordersWaiting'] as num?)?.toInt() ?? 0,
      meters: (j['meters'] as num?)?.toInt() ?? 0,
      rideMinutes: (j['rideMinutes'] as num?)?.toInt() ?? 0,
      stage: _enum(NudgeStage.values, j['stage'], NudgeStage.offered),
      acceptedAt: (j['acceptedAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> nudgeToMap(RelocationNudge n) => {
    'spot': {'name': n.spot.name, 'lat': n.spot.point.latitude, 'lng': n.spot.point.longitude},
    'ordersWaiting': n.ordersWaiting,
    'meters': n.meters,
    'rideMinutes': n.rideMinutes,
    'stage': n.stage.name,
    if (n.acceptedAt != null) 'acceptedAt': Timestamp.fromDate(n.acceptedAt!),
  };

  static RestockRequest? _restock(Map<String, dynamic>? j) {
    if (j == null) return null;
    final s = (j['shortage'] as Map?)?.cast<String, dynamic>();
    return RestockRequest(
      stage: _enum(RestockStage.values, j['stage'], RestockStage.suggested),
      hubName: j['hubName'] as String? ?? '',
      lines: [
        for (final l in (j['lines'] as List?) ?? const [])
          if (l is Map)
            RestockLine(
              itemId: l['itemId'] as String? ?? '',
              name: l['name'] as String? ?? '',
              quantity: (l['quantity'] as num?)?.toInt() ?? 0,
            ),
      ],
      readyInMinutes: (j['readyInMinutes'] as num?)?.toInt(),
      rideMinutes: (j['rideMinutes'] as num?)?.toInt(),
      expiresAt: (j['expiresAt'] as Timestamp?)?.toDate(),
      queueSlot: (j['queueSlot'] as num?)?.toInt(),
      arriveBy: (j['arriveBy'] as Timestamp?)?.toDate(),
      packing: _enum(HubPacking.values, j['packing'], HubPacking.sent),
      readyAt: (j['readyAt'] as Timestamp?)?.toDate(),
      shortage: s == null
          ? null
          : RestockShortage(
              itemName: s['itemName'] as String? ?? '',
              asked: (s['asked'] as num?)?.toInt() ?? 0,
              canGive: (s['canGive'] as num?)?.toInt() ?? 0,
              otherHubName: s['otherHubName'] as String? ?? '',
              otherHubKm: (s['otherHubKm'] as num?)?.toDouble() ?? 0,
              otherHubHas: (s['otherHubHas'] as num?)?.toInt() ?? 0,
            ),
    );
  }

  static Map<String, dynamic> restockToMap(RestockRequest r) => {
    'stage': r.stage.name,
    'hubName': r.hubName,
    'lines': [
      for (final l in r.lines) {'itemId': l.itemId, 'name': l.name, 'quantity': l.quantity},
    ],
    'readyInMinutes': ?r.readyInMinutes,
    'rideMinutes': ?r.rideMinutes,
    if (r.expiresAt != null) 'expiresAt': Timestamp.fromDate(r.expiresAt!),
    'queueSlot': ?r.queueSlot,
    if (r.arriveBy != null) 'arriveBy': Timestamp.fromDate(r.arriveBy!),
    'packing': r.packing.name,
    if (r.readyAt != null) 'readyAt': Timestamp.fromDate(r.readyAt!),
    if (r.shortage case final s?)
      'shortage': {
        'itemName': s.itemName,
        'asked': s.asked,
        'canGive': s.canGive,
        'otherHubName': s.otherHubName,
        'otherHubKm': s.otherHubKm,
        'otherHubHas': s.otherHubHas,
      },
  };

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;

  static AssignedOrder _order(Map<String, dynamic> j) => AssignedOrder(
    id: j['id'] as String? ?? '',
    number: j['number'] as String? ?? '',
    gate: j['gate'] as String? ?? '',
    place: j['place'] as String?,
    items: (j['items'] as num?)?.toInt() ?? 0,
    collectCash: (j['collectCash'] as num?)?.toInt(),
    assignedAt: (j['assignedAt'] as Timestamp?)?.toDate(),
  );
}
