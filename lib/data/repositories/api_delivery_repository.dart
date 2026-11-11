import 'dart:async';
import 'dart:convert';

import 'package:latlong2/latlong.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/delivery_order.dart';
import '../../domain/entities/handover.dart';
import '../../domain/entities/order.dart' show OrderItem;
import '../../domain/entities/problem_report.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../../domain/repositories/handover_repository.dart';
import '../datasources/remote/rider_api_client.dart';
import '../datasources/remote/rider_api_session.dart';
import 'api_online_repository.dart';

/// The order flow on the rider API. The rider packs while stopped, then
/// rides: Order 01's "Navigate" leads to Pack (Handover 01), whose
/// "Packed – go" is `POST /offers/{id}/ready`. The server sees the arrival
/// from the location pings (ARRIVED); there's no gate scan. The handover sends
/// the customer's OTP and the quantities.
class ApiDeliveryRepository implements DeliveryRepository {
  ApiDeliveryRepository(this._session);

  final RiderApiSession _session;

  static const _riding = {'PACKED', 'TIMER_RUNNING'};
  static const _delivered = {'HANDED_OVER', 'COMPLETED'};
  static const _ended = {'CANCELLED', 'FAILED', 'TIMED_OUT', 'NO_SCOOTER', 'PAYMENT_FAILED'};

  @override
  Stream<DeliveryOrder?> watchOrder(String orderId) {
    if (!_session.orders.containsKey(orderId)) {
      unawaited(_session.fetchOrder(orderId).then((_) => _session.notify()));
    }
    return _session.watch(() => _order(orderId));
  }

  DeliveryOrder? _order(String orderId) {
    final json = _session.orders[orderId];
    if (json == null) return null;
    final gate = json['gate'] as Map<String, dynamic>? ?? const {};
    final point = LatLng((gate['lat'] as num? ?? 0).toDouble(), (gate['lng'] as num? ?? 0).toDouble());
    final from = apiSpotPoint(_session);
    final orderState = json['state'] as String?;
    final ended = json['ended_reason'] != null;
    final status = _session.dayList('skippedOrders').contains(orderId)
        ? DeliveryStatus.skipped
        : _delivered.contains(orderState)
        ? DeliveryStatus.delivered
        : ended || _ended.contains(orderState)
        ? DeliveryStatus.cancelled
        : orderState == 'ARRIVED'
        ? DeliveryStatus.atGate
        : _riding.contains(orderState)
        ? DeliveryStatus.onTheWay
        : DeliveryStatus.assigned;
    final fee = ((_session.earnings?['order_earnings'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .where((e) => e['order_id'] == orderId)
        .firstOrNull;
    return DeliveryOrder(
      id: orderId,
      number: apiOrderNumber(json, json['offer_id'] as String? ?? orderId),
      gate: DeliveryGate(name: gate['label'] as String? ?? '', landmark: gate['entry_notes'] as String? ?? '', point: point),
      items: [
        for (final line in (json['items'] as List? ?? const []).cast<Map<String, dynamic>>())
          OrderItem(name: line['name'] as String? ?? '', quantity: (line['qty'] as num?)?.toInt() ?? 0),
      ],
      // `payment_method`: prepaid (paid online, the handover takes the customer's OTP) is the only one so far.
      payment: OrderPayment.upi,
      amount: ApiOnlineRepository.rupeesOf(json['total']).round(),
      // The customer's clock starts when the ride does.
      assignedAt: _session.rideStartOf(orderId) ?? RiderApiSession.parseTime(json['rider_accepted_at']) ?? _session.clock(),
      status: status,
      customerPhone: _session.customerPhones[orderId],
      riderFee: ApiOnlineRepository.rupeesOf(fee?['amount']).round(),
      tripMeters: from == null ? null : const Distance().as(LengthUnit.Meter, from, point),
      gateConfirmedAt: _session.arrivalOf(orderId) ?? RiderApiSession.parseTime(json['handed_over_at']),
    );
  }

  Map<String, dynamic> _known(String orderId) {
    final json = _session.orders[orderId];
    if (json == null) throw const AppException('unknown_order');
    return json;
  }

  /// "Packed – go": the server checks the rider is stopped (rider_moving).
  @override
  Future<void> startNavigation(String orderId) async {
    final json = _known(orderId);
    try {
      final ready = await _session.api.markReady(json['offer_id'] as String, {'fencing_token': json['fencing_token']});
      _session.stampRide(orderId, _session.clock());
      _session.noteOrder(ready['order'] as Map<String, dynamic>);
      _session.notify();
    } on RiderApiException catch (e) {
      if (e.code == 'order_cancelled') await _session.refresh();
      throw AppException(e.code);
    }
  }

  /// The server sees the arrival from the location pings.
  @override
  Future<void> markReachedGate(String orderId) async {}

  /// No gate check in the API.
  @override
  Future<bool> confirmGate(String orderId, GateMethod method, String proof) async => true;

  /// "Can't take this order" (Order 04): `POST /offers/{id}/decline`, no penalty.
  @override
  Future<void> skip(String orderId, SkipReason reason) async {
    final json = _known(orderId);
    try {
      await _session.api.declineOffer(json['offer_id'] as String, {
        'fencing_token': json['fencing_token'],
        'reason': reason.name,
      });
    } on RiderApiException catch (e) {
      throw AppException(e.code);
    }
    await _session.addToDayList('skippedOrders', orderId);
  }

  /// Same order, code and quantities: the same event, so a direct handover
  /// and its queued copy count once.
  String handoverEventId(String orderId, String code, List<Map<String, Object>> quantities) {
    final content = utf8.encode('$orderId|$code|${jsonEncode(quantities)}');
    var hash = 0x811c9dc5;
    for (final byte in content) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    final safe = orderId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '');
    final id = 'ho-$safe-${hash.toRadixString(16).padLeft(8, '0')}';
    return id.length > 128 ? id.substring(0, 128) : id;
  }

  Future<List<Map<String, Object>>> _quantities(String orderId, List<OrderItem> items) async {
    final json = _session.orders[orderId] ?? await _session.fetchOrder(orderId);
    final lines = (json?['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    return [
      for (final line in lines)
        {
          'item_id': line['item_id'] as String,
          'qty': items.where((i) => i.name == line['name']).fold<int>(0, (sum, i) => sum + i.quantity),
        },
    ];
  }

  @override
  Future<bool> completeHandover(HandoverRequest request) async {
    final code = request.code;
    // The API hands over only with the customer's OTP.
    if (request.proof != HandoverProof.code || code == null) throw const AppException('otp_required');
    final quantities = await _quantities(request.orderId, request.items);
    try {
      final json = await _session.api.handOver(
        request.orderId,
        {'client_time': _session.clock().toUtc().toIso8601String(), 'otp': code, 'quantities': quantities},
        idempotencyKey: handoverEventId(request.orderId, code, quantities),
      );
      _session.noteOrder(json['order'] as Map<String, dynamic>);
      _session.notify();
      return true;
    } on RiderApiException catch (e) {
      if (e.code == 'wrong_otp') return false;
      // No way through: saved on the phone, sent with the event batch later.
      if (e.code == 'network' || e.retryable) throw TimeoutException(e.code);
      // order_cancelled, order_reassigned: the order's own state shows it.
      await _session.refresh();
      throw AppException(e.code);
    }
  }

  /// `POST /riders/me/events` with the handover saved without signal.
  @override
  Future<void> syncSavedHandover(SavedHandover saved) async {
    final code = saved.code;
    // Only an OTP handover can go to the API; anything else can't be sent.
    if (saved.proof != HandoverProof.code || code == null) return;
    final quantities = await _quantities(saved.orderId, saved.items);
    final id = handoverEventId(saved.orderId, code, quantities);
    final Map<String, dynamic> result;
    try {
      result = await _session.api.sendEventBatch([
        {
          'event_id': id,
          'type': 'handover',
          'device_time': saved.savedAt.toUtc().toIso8601String(),
          'payload': {'order_id': saved.orderId, 'otp': code, 'quantities': quantities},
        },
      ]);
    } on RiderApiException catch (e) {
      throw AppException(e.code);
    }
    final rejected = (result['rejected'] as List? ?? const []).cast<Map<String, dynamic>>();
    // A retryable rejection waits for the next sync; any other is final.
    if (rejected.any((r) => r['id'] == id && r['retryable'] == true)) throw const AppException('event_retry');
    await _session.refresh();
  }

  /// No such endpoint in the API.
  @override
  Future<void> notifyCustomerWaiting(String orderId) async {}

  /// The location pings carry the rider's position for every order.
  @override
  Future<void> updateRiderLocation(String orderId, LatLng point) async {}
}

/// `POST /riders/me/problems`.
class ApiProblemReportRepository implements ProblemReportRepository {
  ApiProblemReportRepository(this._session);

  final RiderApiSession _session;

  @override
  Future<void> send(ProblemReport report) async {
    final type = switch (report.kind) {
      ProblemKind.breakdown => 'breakdown',
      ProblemKind.accident => 'accident',
      ProblemKind.gateClosed => 'gate_closed',
      ProblemKind.customerAbsent => 'customer_absent',
      ProblemKind.unsafeRoute => 'unsafe_route',
    };
    final events = _session.events;
    try {
      // Without a way through it goes with the event batch later.
      await events.sendOrQueue(
        events.event('problem', {'problem_type': type, 'order_id': ?report.orderId}, at: report.at),
        (key) => _session.api.reportProblem({'type': type, 'order_id': ?report.orderId}, idempotencyKey: key),
      );
    } on RiderApiException catch (e) {
      throw AppException(e.code);
    }
  }
}
