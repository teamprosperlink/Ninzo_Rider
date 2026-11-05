// Firestore has its own Order (index sort order) class.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:latlong2/latlong.dart';

import '../../domain/entities/order.dart';

/// Firestore shape of `orders/{id}`.
class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.orderNumber,
    required super.restaurant,
    required super.customer,
    required super.items,
    required super.total,
    required super.paymentMode,
    required super.riderFee,
    required super.status,
    required super.createdAt,
    super.riderId,
    super.rider,
    super.riderLocation,
    super.acceptedAt,
    super.pickedUpAt,
    super.deliveredAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data()!;
    final status = OrderStatus.values.byName(j['status'] as String);
    final rider = j['rider'] as Map<String, dynamic>?;
    final riderAt = j['riderLocation'] as GeoPoint?;
    return OrderModel(
      id: doc.id,
      orderNumber: '${j['orderNumber'] ?? doc.id.substring(0, 4).toUpperCase()}',
      restaurant: _contact(j['restaurant'] as Map<String, dynamic>),
      customer: _contact(j['customer'] as Map<String, dynamic>),
      items: [
        for (final i in (j['items'] as List?) ?? const [])
          OrderItem(name: i['name'] as String, quantity: (i['qty'] as num?)?.toInt() ?? 1),
      ],
      total: (j['total'] as num).toDouble(),
      paymentMode: PaymentMode.values.asNameMap()[j['paymentMode']] ?? PaymentMode.prepaid,
      riderFee: (j['riderFee'] as num).toDouble(),
      status: status,
      createdAt: _time(j['createdAt'], pending: true)!,
      riderId: j['riderId'] as String?,
      rider: rider == null
          ? null
          : RiderInfo(name: rider['name'] as String, phone: rider['phone'] as String, vehicle: rider['vehicle'] as String),
      riderLocation: riderAt == null ? null : LatLng(riderAt.latitude, riderAt.longitude),
      acceptedAt: _time(j['acceptedAt']),
      pickedUpAt: _time(j['pickedUpAt'], pending: status == OrderStatus.pickedUp),
      deliveredAt: _time(j['deliveredAt'], pending: status == OrderStatus.delivered),
    );
  }

  static Map<String, Object> riderToFirestore(RiderInfo rider) =>
      {'name': rider.name, 'phone': rider.phone, 'vehicle': rider.vehicle};

  static OrderContact _contact(Map<String, dynamic> j) {
    final geo = j['location'] as GeoPoint;
    return OrderContact(
      name: j['name'] as String,
      phone: j['phone'] as String,
      address: j['address'] as String,
      point: LatLng(geo.latitude, geo.longitude),
    );
  }

  /// A server timestamp is null until the write reaches the server; [pending]
  /// fills in the local time meanwhile, so the timer starts right away.
  static DateTime? _time(Object? value, {bool pending = false}) =>
      (value as Timestamp?)?.toDate() ?? (pending ? DateTime.now() : null);
}
