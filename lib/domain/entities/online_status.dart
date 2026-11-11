import 'restock.dart';
import 'shift.dart';
import '../../core/constants/app_strings.dart';

/// An order the system assigned to this rider at the spot (Shift 28). There
/// is no Accept: it's theirs, and the 90 s clock runs from the assignment.
class AssignedOrder {
  const AssignedOrder({
    required this.id,
    required this.number,
    required this.gate,
    required this.items,
    this.collectCash,
    this.assignedAt,
    this.place,
  });

  final String id;

  /// "A2931".
  final String number;

  /// "Gate 3".
  final String gate;

  /// How many items the order has.
  final int items;

  /// Rupees to collect on a cash order; null when it's paid (UPI).
  final int? collectCash;
  final DateTime? assignedAt;

  /// Where the gate is, "Prestige Apts" (Shift 47).
  final String? place;

  AssignedOrder withAssignedAt(DateTime at) => AssignedOrder(
    id: id,
    number: number,
    gate: gate,
    items: items,
    collectCash: collectCash,
    assignedAt: at,
    place: place,
  );
}

/// The day's pay, as Earnings 01 splits it.
class EarningsBreakdown {
  const EarningsBreakdown({this.orderPay = 0, this.incentives = 0, this.repositionMinutes = 0, this.repositionPay = 0});

  final double orderPay;
  final double incentives;
  final int repositionMinutes;
  final double repositionPay;

  double get total => orderPay + incentives + repositionPay;
}

/// What the backend says about a rider who's online. Firestore: fields of
/// `riders/{uid}/shifts/{yyyy-MM-dd}`, see OnlineStatusModel.
class OnlineStatus {
  const OnlineStatus({
    this.onlineAt,
    this.quiet = false,
    this.orders = 0,
    this.earned = 0,
    this.sold = 0,
    this.batteryPercent,
    this.shiftEnd,
    this.queue = const [],
    this.activeOrderId,
    this.stockAdded = 0,
    this.itemsLeft = const [],
    this.breakState,
    this.nudge,
    this.restock,
    this.earnings,
    this.averageDeliverySeconds,
    this.endedAt,
    this.chosenLength,
  });

  /// When the rider first went online at the spot; the Online stat counts
  /// from here. Null before that.
  final DateTime? onlineAt;

  /// No orders around for a while (Shift 27).
  final bool quiet;

  /// Orders delivered this shift.
  final int orders;

  /// Rupees earned this shift.
  final double earned;

  /// Portions gone from the scooter this shift.
  final int sold;

  /// Scooter telemetry, when known.
  final int? batteryPercent;

  /// The shift's end, moved by Add time; null falls back to the shift's.
  final DateTime? shiftEnd;

  /// Assigned orders in delivery order: the first is "Now", the rest wait.
  final List<AssignedOrder> queue;

  /// The order the rider started and hasn't finished: it takes over the
  /// screen (Order 01 onwards) and stays in [queue] until it's done.
  final String? activeOrderId;

  /// Portions refills have added since the day's load.
  final int stockAdded;

  /// What's left on the scooter by item (Refill 01), from the backend.
  final List<ItemLeft> itemsLeft;

  /// A break under way (Shift 44, 45).
  final BreakState? breakState;

  /// The backend's nudge to another spot (Shift 36–39).
  final RelocationNudge? nudge;

  /// A restock suggested or under way (Restock 01–05).
  final RestockRequest? restock;

  /// The day's pay split up (Earnings 01), from the backend.
  final EarningsBreakdown? earnings;

  /// "Average delivery time" (Shift 50), from the backend.
  final int? averageDeliverySeconds;

  /// When the shift ended (Shift 50).
  final DateTime? endedAt;

  /// The hours the rider chose (Shift 46), when the backend has them; else the
  /// shift's own length.
  final Duration? chosenLength;

  OnlineStatus copyWith({
    DateTime? onlineAt,
    bool? quiet,
    int? orders,
    double? earned,
    int? sold,
    int? Function()? batteryPercent,
    DateTime? Function()? shiftEnd,
    List<AssignedOrder>? queue,
    String? Function()? activeOrderId,
    int? stockAdded,
    List<ItemLeft>? itemsLeft,
    BreakState? Function()? breakState,
    RelocationNudge? Function()? nudge,
    RestockRequest? Function()? restock,
    EarningsBreakdown? Function()? earnings,
    int? Function()? averageDeliverySeconds,
    DateTime? Function()? endedAt,
    Duration? Function()? chosenLength,
  }) => OnlineStatus(
    onlineAt: onlineAt ?? this.onlineAt,
    quiet: quiet ?? this.quiet,
    orders: orders ?? this.orders,
    earned: earned ?? this.earned,
    sold: sold ?? this.sold,
    batteryPercent: batteryPercent == null ? this.batteryPercent : batteryPercent(),
    shiftEnd: shiftEnd == null ? this.shiftEnd : shiftEnd(),
    queue: queue ?? this.queue,
    activeOrderId: activeOrderId == null ? this.activeOrderId : activeOrderId(),
    stockAdded: stockAdded ?? this.stockAdded,
    itemsLeft: itemsLeft ?? this.itemsLeft,
    breakState: breakState == null ? this.breakState : breakState(),
    nudge: nudge == null ? this.nudge : nudge(),
    restock: restock == null ? this.restock : restock(),
    earnings: earnings == null ? this.earnings : earnings(),
    averageDeliverySeconds: averageDeliverySeconds == null ? this.averageDeliverySeconds : averageDeliverySeconds(),
    endedAt: endedAt == null ? this.endedAt : endedAt(),
    chosenLength: chosenLength == null ? this.chosenLength : chosenLength(),
  );
}

/// How much of one menu item is left (Refill 01).
class ItemLeft {
  const ItemLeft({required this.name, required this.left});

  final String name;
  final int left;
}

/// How long a break lasts (Shift 43).
enum BreakOption {
  min15(Duration(minutes: 15), AppStrings.text15Min2),
  min30(Duration(minutes: 30), AppStrings.text30Min),
  min45(Duration(minutes: 45), AppStrings.text45Min),
  hr1(Duration(hours: 1), AppStrings.text1Hr);

  const BreakOption(this.duration, this.label);

  final Duration duration;
  final String label;
}

/// A break under way. Time up (Shift 45) changes nothing by itself: orders
/// stay paused until "Back online".
class BreakState {
  const BreakState({required this.startedAt, required this.length});

  final DateTime startedAt;
  final Duration length;

  DateTime get endsAt => startedAt.add(length);

  bool isOver(DateTime now) => !now.isBefore(endsAt);

  /// Shift 44's clock; negative past the end.
  Duration left(DateTime now) => endsAt.difference(now);

  /// How much of the break has gone, 0 to 1.
  double progress(DateTime now) {
    final gone = now.difference(startedAt).inMilliseconds / length.inMilliseconds;
    return gone.clamp(0.0, 1.0);
  }
}

/// Where the nudge stands.
enum NudgeStage {
  /// Shift 36.
  offered,

  /// Shift 39: another rider took it.
  covered,

  /// Shift 37, 38: the rider is on the way.
  accepted,
}

/// "Orders waiting at Jakkur Node".
class RelocationNudge {
  const RelocationNudge({
    required this.spot,
    required this.ordersWaiting,
    required this.meters,
    required this.rideMinutes,
    this.stage = NudgeStage.offered,
    this.acceptedAt,
  });

  final Spot spot;
  final int ordersWaiting;
  final int meters;
  final int rideMinutes;
  final NudgeStage stage;

  /// The paid time runs from here (Shift 37).
  final DateTime? acceptedAt;

  RelocationNudge accepted(DateTime at) => RelocationNudge(
    spot: spot,
    ordersWaiting: ordersWaiting,
    meters: meters,
    rideMinutes: rideMinutes,
    stage: NudgeStage.accepted,
    acceptedAt: at,
  );

  RelocationNudge get covered => RelocationNudge(
    spot: spot,
    ordersWaiting: ordersWaiting,
    meters: meters,
    rideMinutes: rideMinutes,
    stage: NudgeStage.covered,
  );
}

/// What's on the scooter (the row above the actions, the low-stock banner).
class ScooterStock {
  const ScooterStock({required this.kinds, required this.portionsLeft});

  /// Different menu items loaded, e.g. 4.
  final int kinds;

  /// Portions still on the scooter, e.g. 6.
  final int portionsLeft;

  /// Low-stock banner at this many items or fewer.
  static const lowStockAt = 5;

  bool get isLow => portionsLeft <= lowStockAt;

  /// "N items on scooter": the load's menu items (Shift 26: 4 items, 6
  /// portions), and the real count of what's left once it runs low (Shift
  /// 29: 5).
  int get shown => isLow ? portionsLeft : kinds;
}

/// How long Keep riding adds (Shift 33).
enum AddTimeOption {
  min15(Duration(minutes: 15), AppStrings.text15Min2),
  min30(Duration(minutes: 30), AppStrings.text30Min),
  min45(Duration(minutes: 45), AppStrings.text45Min),
  hr1(Duration(hours: 1), AppStrings.text1Hr),
  hrs2(Duration(hours: 2), AppStrings.text2Hrs),
  hrs3(Duration(hours: 3), AppStrings.text3Hrs),
  hrs4(Duration(hours: 4), AppStrings.text4Hrs);

  const AddTimeOption(this.duration, this.label);

  final Duration duration;
  final String label;
}

/// The banner over the main map; one at a time, see SelectOnlineAlert.
sealed class OnlineAlert {
  const OnlineAlert();
}

/// Shift 40. [waiting] deliveries are saved on the phone.
class ConnectionLostAlert extends OnlineAlert {
  const ConnectionLostAlert(this.waiting);

  final int waiting;
}

/// Shift 35.
class TimeAddedAlert extends OnlineAlert {
  const TimeAddedAlert(this.end);

  final DateTime end;
}

/// Shift 30.
class AwayFromSpotAlert extends OnlineAlert {
  const AwayFromSpotAlert(this.meters);

  final double meters;
}

/// Shift 32.
class ShiftEndingAlert extends OnlineAlert {
  const ShiftEndingAlert(this.minutesLeft);

  final int minutesLeft;
}

/// Shift 31.
class BatteryLowAlert extends OnlineAlert {
  const BatteryLowAlert(this.percent);

  final int percent;
}

/// Shift 29.
class LowStockAlert extends OnlineAlert {
  const LowStockAlert(this.left);

  final int left;
}

/// Shift 36.
class RelocationNudgeAlert extends OnlineAlert {
  const RelocationNudgeAlert(this.nudge);

  final RelocationNudge nudge;
}

/// Shift 39.
class NudgeCoveredAlert extends OnlineAlert {
  const NudgeCoveredAlert(this.nudge);

  final RelocationNudge nudge;
}

/// What the main map's sheet is saying.
enum OnlineMode {
  /// Shift 25: just confirmed by the rider.
  spotConfirmed,

  /// Shift 26 (and 29, 31, 32, 35 with their banners).
  waiting,

  /// Shift 27.
  quiet,

  /// Shift 28.
  orderAssigned,

  /// Shift 30.
  away,
}
