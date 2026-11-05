import '../../domain/entities/delivery_order.dart';
import '../../domain/entities/handover.dart';
import '../../domain/entities/order.dart' show OrderItem;

/// The phone's copy of saved handovers as JSON.
abstract final class HandoverLocalJson {
  static Map<String, dynamic> encode(HandoverLocalState state) => {
    'lastSync': state.lastSync?.toIso8601String(),
    'saved': [for (final s in state.saved) _encode(s)],
  };

  static HandoverLocalState decode(Map<String, dynamic> j) => HandoverLocalState(
    lastSync: DateTime.tryParse(j['lastSync'] as String? ?? ''),
    saved: [
      for (final s in (j['saved'] as List?) ?? const [])
        if (s is Map) _decode(s.cast<String, dynamic>()),
    ],
  );

  static Map<String, dynamic> _encode(SavedHandover s) => {
    'orderId': s.orderId,
    'number': s.number,
    'gateName': s.gateName,
    'proof': s.proof.name,
    'code': s.code,
    'items': [
      for (final i in s.items) {'name': i.name, 'qty': i.quantity},
    ],
    'payment': s.payment.name,
    'amount': s.amount,
    'riderFee': s.riderFee,
    'assignedAt': s.assignedAt.toIso8601String(),
    'gateConfirmedAt': s.gateConfirmedAt?.toIso8601String(),
    'savedAt': s.savedAt.toIso8601String(),
    'released': s.released,
  };

  static SavedHandover _decode(Map<String, dynamic> j) => SavedHandover(
    orderId: j['orderId'] as String,
    number: j['number'] as String,
    gateName: j['gateName'] as String? ?? '',
    proof: HandoverProof.values.asNameMap()[j['proof']] ?? HandoverProof.none,
    code: j['code'] as String?,
    items: [
      for (final i in (j['items'] as List?) ?? const [])
        if (i is Map) OrderItem(name: i['name'] as String? ?? '', quantity: (i['qty'] as num?)?.toInt() ?? 1),
    ],
    payment: OrderPayment.values.asNameMap()[j['payment']] ?? OrderPayment.upi,
    amount: (j['amount'] as num?)?.toInt() ?? 0,
    riderFee: (j['riderFee'] as num?)?.toInt() ?? 0,
    assignedAt: DateTime.parse(j['assignedAt'] as String),
    gateConfirmedAt: DateTime.tryParse(j['gateConfirmedAt'] as String? ?? ''),
    savedAt: DateTime.parse(j['savedAt'] as String),
    released: j['released'] as bool? ?? false,
  );
}
