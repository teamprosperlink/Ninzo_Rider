import 'package:latlong2/latlong.dart';

import 'order.dart' show OrderItem;
import 'rider_settings.dart';
import '../../core/constants/app_strings.dart';

/// How the customer pays: UPI or cash on delivery, nothing else.
enum OrderPayment {
  upi(AppStrings.upi),
  cash(AppStrings.cashOnDelivery);

  const OrderPayment(this.label);

  final String label;
}

/// assigned → onTheWay → atGate → delivered. The rider can skip an assigned
/// order; the customer can cancel until it's handed over.
enum DeliveryStatus {
  /// Order 01. Auto-assigned at the spot: there's no Accept, and the clock is
  /// running.
  assigned,

  /// Order 02, 03, Navigate 01–03.
  onTheWay,

  /// The gate is confirmed (Arrival 03); Handover comes next.
  atGate,

  delivered,

  /// Order 05.
  skipped,

  /// Navigate 04–06.
  cancelled,
}

/// Why the rider skips an order (Order 04). The reasons offered are the
/// rider API's (`GET /riders/me/settings`); [name] is the code sent back.
class SkipReason {
  const SkipReason(this.name, this.label);

  final String name;
  final String label;

  static const scooterProblem = SkipReason('scooterProblem', AppStrings.scooterProblem);
  static const itemMissing = SkipReason('itemMissing', AppStrings.itemMissingOrDamaged);
  static const notSafe = SkipReason('notSafe', AppStrings.notSafeToRide);
  static const somethingElse = SkipReason('somethingElse', AppStrings.somethingElse);

  static List<SkipReason> get values => RiderSettings.current.skipReasons;

  @override
  bool operator ==(Object other) => other is SkipReason && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// How the rider proves they're at the gate; location alone can't.
enum GateMethod { qr, code }

/// Where the order goes.
class DeliveryGate {
  const DeliveryGate({required this.name, required this.landmark, required this.point});

  /// "Gate 3".
  final String name;

  /// "Main entrance".
  final String landmark;
  final LatLng point;
}

/// An order assigned to this rider. Firestore: `orders/{id}`, see
/// DeliveryOrderModel.
class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.number,
    required this.gate,
    required this.items,
    required this.payment,
    required this.amount,
    required this.assignedAt,
    this.status = DeliveryStatus.assigned,
    this.customerPhone,
    this.skipReason,
    this.riderFee = 0,
    this.tripMeters,
    this.gateConfirmedAt,
  });

  final String id;

  /// "A2931".
  final String number;
  final DeliveryGate gate;

  /// With quantities: "Smash Burger × 2".
  final List<OrderItem> items;
  final OrderPayment payment;

  /// What the customer pays, in rupees.
  final int amount;

  /// The 90 s clock runs from here.
  final DateTime assignedAt;
  final DeliveryStatus status;

  /// The masked number that reaches the customer.
  final String? customerPhone;
  final SkipReason? skipReason;

  /// What the rider earns for it, in rupees (Handover 06, 11).
  final int riderFee;

  /// From the spot to the gate (Handover 01), when known.
  final double? tripMeters;

  /// "Time to gate" runs up to here.
  final DateTime? gateConfirmedAt;

  /// Portions in the order; "3 items" on Handover 13.
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  DeliveryOrder copyWith({
    DeliveryStatus? status,
    OrderPayment? payment,
    int? amount,
    DateTime? assignedAt,
    SkipReason? skipReason,
    DateTime? gateConfirmedAt,
    int? riderFee,
  }) => DeliveryOrder(
    id: id,
    number: number,
    gate: gate,
    items: items,
    payment: payment ?? this.payment,
    amount: amount ?? this.amount,
    assignedAt: assignedAt ?? this.assignedAt,
    status: status ?? this.status,
    customerPhone: customerPhone,
    skipReason: skipReason ?? this.skipReason,
    riderFee: riderFee ?? this.riderFee,
    tripMeters: tripMeters,
    gateConfirmedAt: gateConfirmedAt ?? this.gateConfirmedAt,
  );
}

/// The 90 s clock at one moment.
class OrderClock {
  const OrderClock({required this.secondsLeft, required this.late});

  /// Whole seconds left; 0 once over.
  final int secondsLeft;

  /// Past the 90 s: Order 03.
  final bool late;

  /// For the ring: 1 is full.
  double get progress => secondsLeft / OrderRules.window.inSeconds;
}

abstract final class OrderRules {
  /// Rupees: the most a cancelled prepaid order pays for the trip (`cancel_pay_cap`).
  static int get cancelPayCap => RiderSettings.current.cancelPayCap;

  /// From assignment to the customer: the zone's timer (`timer_length_s`).
  static Duration get window => RiderSettings.current.timerLength;
}

/// Which way the customer's cancellation pays the rider.
enum CancellationKind {
  /// Navigate 04: UPI, ₹20 or more.
  upiFlat,

  /// Navigate 05: cash has no cancellation charge, so no trip pay.
  cash,

  /// Navigate 06: UPI, under ₹20: the full order amount.
  upiFull,
}

class CancellationPay {
  const CancellationPay(this.kind, this.tripPay);

  final CancellationKind kind;

  /// Rupees.
  final int tripPay;
}

/// What's wrong with the way to the gate (Navigate 01–03).
enum RouteIssue { weakSignal, roadClosed, offRoute }
