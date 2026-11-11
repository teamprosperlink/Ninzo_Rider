import 'package:latlong2/latlong.dart';

/// Where the rider's stock for the day stands with the hub.
///
/// One hour before the shift the rider is asked to confirm they're coming
/// (Notification 05); the hub packs only after a yes. No reply: a reminder
/// at 30 minutes (Notification 06) and nothing is packed.
enum StockRequestStatus {
  /// The hub hasn't been told (Shift 01).
  notRequested,

  /// The 1-hour push went out; no reply yet (Shift 01).
  awaitingReply,

  /// The rider answered "Not today" (Shift 02).
  notWorkingToday,

  /// The rider confirmed (or asked the hub to prepare); the hub hasn't
  /// accepted yet. Together with [packing], "confirmed, hub preparing"
  /// (Shift 03).
  requested,

  /// The hub accepted and is packing (Shift 03, 53).
  packing,

  /// Packed and waiting at the hub (Notification 07, Shift 04).
  ready;

  /// The hub knows the rider is coming.
  bool get confirmed => this == requested || this == packing || this == ready;
}

/// The rider's day, in order. Persisted with the shift so it survives an app
/// restart; each later section moves it forward.
enum ShiftPhase {
  /// Home before Start riding (Shift 01–05).
  notStarted,

  /// Start riding tapped: pre-shift checklist (Shift 10–12).
  checklist,

  /// On the way to the hub (Shift 52; Home shows Shift 07).
  headingToHub,

  /// At the hub: waiting for packing (Shift 53) or collecting the packed
  /// stock (Refill 03).
  atHub,

  /// Scanning stock onto the scooter (Stock 01–16; Home shows Shift 08).
  scanning,

  /// Stock scanned and confirmed (Stock 06; Home shows Shift 09). Go online
  /// unlocks.
  stockLoaded,

  /// Heading to the spot after Go online, or back to it (Shift 19–24).
  headingToSpot,

  /// At the spot, online and getting orders (Shift 25–35).
  online,

  /// Go offline ends the shift (Shift 48–50).
  ended;

  bool isBefore(ShiftPhase other) => index < other.index;
}

/// Hub that packs the rider's stock, assigned by the system.
class Hub {
  const Hub({required this.id, required this.name, required this.area, required this.point, this.managerPhone});

  final String id;

  /// e.g. "Hub 2".
  final String name;

  /// e.g. "Yelahanka".
  final String area;
  final LatLng point;

  /// "Call hub manager" (Profile 02, 09), when the backend gives one.
  final String? managerPhone;
}

/// Spot the rider waits at for orders, assigned by the system.
class Spot {
  const Spot({required this.name, required this.point});

  /// e.g. "Yelahanka Node".
  final String name;
  final LatLng point;
}

/// The electric scooter provided by Ninzo.
class Scooter {
  const Scooter({required this.plate, this.batteryPercent});

  /// e.g. "KA 01 AB 1234".
  final String plate;

  /// From the scooter's telemetry, when known.
  final int? batteryPercent;

  /// Charge needed to ride a whole shift.
  static const minBatteryPercent = 40;

  /// At or below this the main map warns (Shift 31).
  // TODO(design): Figma marks this "on hold" until the battery level and
  // scooter type are decided.
  static const lowBatteryPercent = 20;

  bool get batteryOk => (batteryPercent ?? 100) >= minBatteryPercent;
}

/// Today's load: what the hub packed and how much has been scanned onto
/// the scooter.
class StockLoad {
  const StockLoad({this.items = 0, this.portions = 0, this.scanned = 0});

  /// Different menu items, e.g. 4.
  final int items;

  /// Portions in total, e.g. 6.
  final int portions;

  /// Portions scanned onto the scooter.
  final int scanned;

  bool get allScanned => portions > 0 && scanned >= portions;

  StockLoad copyWith({int? items, int? portions, int? scanned}) =>
      StockLoad(items: items ?? this.items, portions: portions ?? this.portions, scanned: scanned ?? this.scanned);
}

/// A refill under way (Refill 03, scanning, Refill 04).
class RefillLoad {
  const RefillLoad({required this.hubName});

  /// The hub it's collected from; a restock may move to another (Restock 05).
  final String hubName;
}

/// One day's shift: when, where, with which scooter, and how far the rider
/// has got. Firestore `riders/{uid}/shifts/{yyyy-MM-dd}`.
class Shift {
  const Shift({
    required this.id,
    required this.start,
    required this.end,
    required this.hub,
    required this.spot,
    required this.scooter,
    this.stockRequest = StockRequestStatus.notRequested,
    this.stockReadyAt,
    this.phase = ShiftPhase.notStarted,
    this.stock = const StockLoad(),
    this.hubDistanceKm,
    this.refill,
    this.refillRound = 0,
  });

  /// The day, "yyyy-MM-dd".
  final String id;
  final DateTime start;
  final DateTime end;
  final Hub hub;
  final Spot spot;
  final Scooter scooter;
  final StockRequestStatus stockRequest;

  /// When the hub expects to finish packing (Shift 53 "Ready in").
  final DateTime? stockReadyAt;
  final ShiftPhase phase;
  final StockLoad stock;

  /// Road distance from the rider's home area to the hub, from the backend;
  /// the live position replaces it when known.
  final double? hubDistanceKm;

  /// The refill under way; null the rest of the day.
  final RefillLoad? refill;

  /// How many refills were started. Each is a load of its own.
  final int refillRound;

  /// The load being scanned: the day's, or the latest refill's.
  String get stockLoadId => loadIdFor(id, refillRound);

  /// The load of refill [round] of shift [shiftId]; 0 is the day's own.
  static String loadIdFor(String shiftId, int round) => round == 0 ? shiftId : '$shiftId-refill$round';

  bool hasStarted(DateTime now) => !now.isBefore(start);

  Shift copyWith({
    StockRequestStatus? stockRequest,
    DateTime? Function()? stockReadyAt,
    ShiftPhase? phase,
    StockLoad? stock,
    DateTime? start,
    DateTime? end,
    Spot? spot,
    RefillLoad? Function()? refill,
    int? refillRound,
  }) => Shift(
    id: id,
    start: start ?? this.start,
    end: end ?? this.end,
    hub: hub,
    spot: spot ?? this.spot,
    scooter: scooter,
    stockRequest: stockRequest ?? this.stockRequest,
    stockReadyAt: stockReadyAt == null ? this.stockReadyAt : stockReadyAt(),
    phase: phase ?? this.phase,
    stock: stock ?? this.stock,
    hubDistanceKm: hubDistanceKm,
    refill: refill == null ? this.refill : refill(),
    refillRound: refillRound ?? this.refillRound,
  );

  /// "yyyy-MM-dd" for [day].
  static String idFor(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}
