import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/shift.dart';

/// Maps `riders/{uid}/shifts/{yyyy-MM-dd}`:
///
/// ```
/// start, end            Timestamp
/// hub                   {id, name, area, lat, lng, managerPhone}
/// spot                  {name, lat, lng}
/// scooter               {plate, batteryPercent}
/// stockRequest          notRequested | awaitingReply | notWorkingToday |
///                       requested | packing | ready
/// stockReadyAt          Timestamp (hub's estimate while packing)
/// phase                 notStarted | checklist | headingToHub | atHub |
///                       scanning | stockLoaded | headingToSpot | online | ended
/// stock                 {items, portions, scanned}
/// hubDistanceKm         number
/// refill                {hubName} (rider: while a refill is under way)
/// refillRound           number (rider: refills started)
/// openOn                string (rider: the phone holding the shift, Shift 54)
/// ```
abstract final class ShiftModel {
  static Shift fromFirestore(String id, Map<String, dynamic> j) {
    final hub = (j['hub'] as Map?)?.cast<String, dynamic>() ?? const {};
    final spot = (j['spot'] as Map?)?.cast<String, dynamic>() ?? const {};
    final scooter = (j['scooter'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stock = (j['stock'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Shift(
      id: id,
      start: (j['start'] as Timestamp).toDate(),
      end: (j['end'] as Timestamp).toDate(),
      hub: Hub(
        id: hub['id'] as String? ?? '',
        name: hub['name'] as String? ?? '',
        area: hub['area'] as String? ?? '',
        point: _point(hub),
        managerPhone: hub['managerPhone'] as String?,
      ),
      spot: Spot(name: spot['name'] as String? ?? '', point: _point(spot)),
      scooter: Scooter(
        plate: scooter['plate'] as String? ?? '',
        batteryPercent: (scooter['batteryPercent'] as num?)?.round(),
      ),
      stockRequest: _enum(StockRequestStatus.values, j['stockRequest'], StockRequestStatus.notRequested),
      stockReadyAt: (j['stockReadyAt'] as Timestamp?)?.toDate(),
      phase: _enum(ShiftPhase.values, j['phase'], ShiftPhase.notStarted),
      stock: StockLoad(
        items: (stock['items'] as num?)?.toInt() ?? 0,
        portions: (stock['portions'] as num?)?.toInt() ?? 0,
        scanned: (stock['scanned'] as num?)?.toInt() ?? 0,
      ),
      hubDistanceKm: (j['hubDistanceKm'] as num?)?.toDouble(),
      refill: switch ((j['refill'] as Map?)?['hubName']) {
        final String hubName => RefillLoad(hubName: hubName),
        _ => null,
      },
      refillRound: (j['refillRound'] as num?)?.toInt() ?? 0,
    );
  }

  static LatLng _point(Map<String, dynamic> j) =>
      LatLng((j['lat'] as num?)?.toDouble() ?? 0, (j['lng'] as num?)?.toDouble() ?? 0);

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;
}
