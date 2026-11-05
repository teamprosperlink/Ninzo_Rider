// Firestore has its own Order (index sort order) class.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:latlong2/latlong.dart';

import '../../domain/entities/delivery_order.dart';
import '../../domain/entities/handover.dart';
import '../../domain/entities/order.dart' show Order, OrderItem;

/// Maps `orders/{id}` as the order flow uses it:
///
/// ```
/// orderNumber     string (backend)
/// riderId         string (backend)
/// gate            {name, landmark, lat, lng} (backend)
/// items           [{name, qty}] (backend)
/// payment         'upi' | 'cash' (backend)
/// amount          number, rupees (backend)
/// riderFee        number, rupees: what the rider earns (backend)
/// tripMeters      number: from the spot to the gate (backend)
/// customerPhone   string, masked (backend)
/// assignedAt      Timestamp (backend): the 90 s clock runs from here
/// status          assigned → onTheWay → atGate → delivered (rider), skipped
///                 (rider), cancelled (backend)
/// navigatingAt, reachedGateAt, gateConfirmedAt, skippedAt   Timestamp (rider)
/// gateMethod      'qr' | 'code', gateProof string (rider; the rules check it
///                 against orders/{id}/private/gate {qr, code})
/// skipReason      SkipReason name (rider)
/// riderLocation   GeoPoint (rider)
/// customerWaitingAt  Timestamp (rider): Handover 07, the backend tells the customer
/// handoverMethod  'code' | 'cash' | 'details' | 'offline' (rider)
/// deliveryCode    string (rider; the rules check it against orders/{id}/private/code)
/// handedOver      [{name, qty}] (rider): what the customer got
/// deliveredAt     Timestamp (rider)
/// offlineProof, handoverCode, handedOverAt  (rider): a handover saved without
///                 signal; the backend checks handoverCode afterwards
/// ```
abstract final class DeliveryOrderModel {
  static DeliveryOrder fromFirestore(String id, Map<String, dynamic> j) {
    final gate = (j['gate'] as Map?)?.cast<String, dynamic>() ?? const {};
    return DeliveryOrder(
      id: id,
      number: '${j['orderNumber'] ?? id}',
      gate: DeliveryGate(
        name: gate['name'] as String? ?? '',
        landmark: gate['landmark'] as String? ?? '',
        point: LatLng((gate['lat'] as num?)?.toDouble() ?? 0, (gate['lng'] as num?)?.toDouble() ?? 0),
      ),
      items: [
        for (final i in (j['items'] as List?) ?? const [])
          if (i is Map) OrderItem(name: i['name'] as String? ?? '', quantity: (i['qty'] as num?)?.toInt() ?? 1),
      ],
      payment: OrderPayment.values.asNameMap()[j['payment']] ?? OrderPayment.upi,
      amount: (j['amount'] as num?)?.toInt() ?? 0,
      // A server timestamp is null until the write reaches the server.
      assignedAt: (j['assignedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: DeliveryStatus.values.asNameMap()[j['status']] ?? DeliveryStatus.assigned,
      customerPhone: j['customerPhone'] as String?,
      skipReason: SkipReason.values.asNameMap()[j['skipReason']],
      riderFee: (j['riderFee'] as num?)?.toInt() ?? 0,
      tripMeters: (j['tripMeters'] as num?)?.toDouble(),
      gateConfirmedAt: (j['gateConfirmedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// A delivered order of this flow, for the delivery history.
  static Order historyOrder(String id, Map<String, dynamic> j) {
    final order = fromFirestore(id, j);
    final handed = (j['handedOver'] as List?) ?? const [];
    return deliveredHistoryOrder(
      id: id,
      number: order.number,
      gateName: order.gate.name,
      items: handed.isEmpty
          ? order.items
          : [
              for (final i in handed)
                if (i is Map) OrderItem(name: i['name'] as String? ?? '', quantity: (i['qty'] as num?)?.toInt() ?? 1),
            ],
      payment: order.payment,
      amount: order.amount,
      riderFee: order.riderFee,
      assignedAt: order.assignedAt,
      gateConfirmedAt: order.gateConfirmedAt,
      deliveredAt: (j['deliveredAt'] as Timestamp?)?.toDate() ?? order.assignedAt,
      riderId: j['riderId'] as String?,
    );
  }
}
