import '../../../core/api/api_endpoints.dart';
import 'rider_api_client.dart';

/// Every rider API call, one method each, as the contract names them. The
/// repositories use these; nothing else in the app builds a URL.
class RiderApi {
  RiderApi(this.client);

  final RiderApiClient client;

  // ── Sign-in ──
  Future<Map<String, dynamic>> requestOtp(String phone) =>
      client.post(RiderApiEndpoints.otpRequest, body: {'phone': phone}, auth: false);

  Future<Map<String, dynamic>> verifyOtp(String requestId, String otp) =>
      client.post(RiderApiEndpoints.otpVerify, body: {'request_id': requestId, 'otp': otp}, auth: false);

  Future<Map<String, dynamic>> signOut() => client.post(RiderApiEndpoints.signOut);

  // ── Rider ──
  Future<Map<String, dynamic>> getRider() => client.get(RiderApiEndpoints.me);
  Future<Map<String, dynamic>> getRiderState() => client.get(RiderApiEndpoints.state);
  Future<Map<String, dynamic>> registerDevice(Map<String, dynamic> device) =>
      client.post(RiderApiEndpoints.devices, body: device, idempotent: true);
  Future<Map<String, dynamic>> removeDevice(String deviceId) =>
      client.delete(RiderApiEndpoints.device(deviceId), idempotent: true);
  Future<Map<String, dynamic>> getVerification() => client.get(RiderApiEndpoints.verification);
  Future<Map<String, dynamic>> startVerification(Map<String, dynamic> body) =>
      client.post(RiderApiEndpoints.verificationStart, body: body, idempotent: true);
  Future<Map<String, dynamic>> getEarnings({String? date}) =>
      client.get(RiderApiEndpoints.earnings, query: {'date': ?date});
  Future<Map<String, dynamic>> reportProblem(Map<String, dynamic> problem, {String? idempotencyKey}) =>
      client.post(RiderApiEndpoints.problems, body: problem, idempotent: true, idempotencyKey: idempotencyKey);
  Future<Map<String, dynamic>> sendEventBatch(List<Map<String, dynamic>> events) =>
      client.post(RiderApiEndpoints.events, body: {'events': events});
  Future<Map<String, dynamic>> locationPing(Map<String, dynamic> ping) =>
      client.post(RiderApiEndpoints.location, body: ping);

  // ── Shift and spots ──
  Future<Map<String, dynamic>> listNodes({String? zoneId}) =>
      client.get(RiderApiEndpoints.nodes, query: {'zone_id': ?zoneId});
  Future<Map<String, dynamic>> startShift(Map<String, dynamic> body) =>
      client.post(RiderApiEndpoints.shiftStart, body: body, idempotent: true);
  Future<Map<String, dynamic>> endShift() => client.post(RiderApiEndpoints.shiftEnd, idempotent: true);
  Future<Map<String, dynamic>> acceptRelocation(String relocationId) =>
      client.post(RiderApiEndpoints.acceptRelocation(relocationId), idempotent: true);

  // ── Stock ──
  Future<Map<String, dynamic>> getStock() => client.get(RiderApiEndpoints.stock);
  Future<Map<String, dynamic>> scanStock(Map<String, dynamic> scan, {String? idempotencyKey}) =>
      client.post(RiderApiEndpoints.stockScan, body: scan, idempotent: true, idempotencyKey: idempotencyKey);

  // ── Offers and orders ──
  Future<Map<String, dynamic>> listOffers() => client.get(RiderApiEndpoints.offers);
  Future<Map<String, dynamic>> acceptOffer(String offerId, Map<String, dynamic> body) =>
      client.post(RiderApiEndpoints.acceptOffer(offerId), body: body, idempotent: true);
  Future<Map<String, dynamic>> declineOffer(String offerId, Map<String, dynamic> body) =>
      client.post(RiderApiEndpoints.declineOffer(offerId), body: body, idempotent: true);
  Future<Map<String, dynamic>> markReady(String offerId, Map<String, dynamic> body) =>
      client.post(RiderApiEndpoints.markReady(offerId), body: body, idempotent: true);
  Future<Map<String, dynamic>> getOrder(String orderId) => client.get(RiderApiEndpoints.order(orderId));
  Future<Map<String, dynamic>> getRoute(String orderId) => client.get(RiderApiEndpoints.orderRoute(orderId));
  Future<Map<String, dynamic>> startMaskedCall(String orderId) =>
      client.post(RiderApiEndpoints.orderCall(orderId), idempotent: true);
  Future<Map<String, dynamic>> handOver(String orderId, Map<String, dynamic> body, {String? idempotencyKey}) =>
      client.post(RiderApiEndpoints.handover(orderId), body: body, idempotent: true, idempotencyKey: idempotencyKey);

  // ── Restock ──
  Future<Map<String, dynamic>> createRestock(Map<String, dynamic> body) =>
      client.post(RiderApiEndpoints.restock, body: body, idempotent: true);
  Future<Map<String, dynamic>> getRestockOptions() => client.get(RiderApiEndpoints.restockOptions);
  Future<Map<String, dynamic>> listRestockSuggestions() => client.get(RiderApiEndpoints.restockSuggestions);
  Future<Map<String, dynamic>> getRestock(String requestId) => client.get(RiderApiEndpoints.restockRequest(requestId));
  Future<Map<String, dynamic>> confirmRestock(String requestId, Map<String, dynamic> body, {String? idempotencyKey}) =>
      client.post(
        RiderApiEndpoints.confirmRestock(requestId),
        body: body,
        idempotent: true,
        idempotencyKey: idempotencyKey,
      );
  Future<Map<String, dynamic>> declineRestock(String requestId, Map<String, dynamic> body, {String? idempotencyKey}) =>
      client.post(
        RiderApiEndpoints.declineRestock(requestId),
        body: body,
        idempotent: true,
        idempotencyKey: idempotencyKey,
      );
  Future<Map<String, dynamic>> respondToShortfall(String requestId, Map<String, dynamic> body) =>
      client.post(RiderApiEndpoints.restockShortfallResponse(requestId), body: body, idempotent: true);
}
