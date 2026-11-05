import 'package:latlong2/latlong.dart';

/// ready → accepted → pickedUp → delivered. The kitchen (or backend) creates
/// the order as `ready`; it can cancel it until it is picked up.
enum OrderStatus {
  ready,
  accepted,
  pickedUp,
  delivered,
  cancelled;

  /// A rider is assigned and the order is not handed over yet.
  bool get isActive => this == accepted || this == pickedUp;
}

enum PaymentMode { cash, prepaid }

/// The restaurant or the customer of an order.
class OrderContact {
  const OrderContact({required this.name, required this.phone, required this.address, required this.point});

  final String name;
  final String phone;
  final String address;
  final LatLng point;
}

class OrderItem {
  const OrderItem({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

/// Rider details copied onto an order so the customer and kitchen can see them.
class RiderInfo {
  const RiderInfo({required this.name, required this.phone, required this.vehicle});

  final String name;
  final String phone;

  /// e.g. "Motorbike • DL 3S AB 1234".
  final String vehicle;
}

class Order {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.restaurant,
    required this.customer,
    required this.items,
    required this.total,
    required this.paymentMode,
    required this.riderFee,
    required this.status,
    required this.createdAt,
    this.riderId,
    this.rider,
    this.riderLocation,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
  });

  /// Time from pickup to handover that NinzoRider promises the customer.
  static const deliveryWindow = Duration(seconds: 90);

  final String id;

  /// Short number the kitchen and customer use, e.g. "1042".
  final String orderNumber;
  final OrderContact restaurant;
  final OrderContact customer;
  final List<OrderItem> items;

  /// Amount the customer pays, food included.
  final double total;
  final PaymentMode paymentMode;

  /// What the rider earns for this delivery.
  final double riderFee;
  final OrderStatus status;
  final DateTime createdAt;
  final String? riderId;
  final RiderInfo? rider;
  final LatLng? riderLocation;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  /// Distance from the restaurant to the customer.
  double get tripKm => kmBetween(restaurant.point, customer.point);

  bool get collectCash => paymentMode == PaymentMode.cash;

  /// When the order must be handed over; null until picked up.
  DateTime? get deadline => pickedUpAt?.add(deliveryWindow);

  /// Pickup to handover; null until delivered.
  Duration? get deliveryTime =>
      (pickedUpAt != null && deliveredAt != null) ? deliveredAt!.difference(pickedUpAt!) : null;

  bool get deliveredOnTime => deliveryTime != null && deliveryTime! <= deliveryWindow;

  static double kmBetween(LatLng a, LatLng b) => const Distance()(a, b) / 1000;
}
