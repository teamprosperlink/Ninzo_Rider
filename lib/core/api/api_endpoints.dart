/// Every endpoint the app talks to, in one place: the Ninzo rider API, its
/// live stream and Google (Places, Geocoding, Routes, Maps directions).
/// Nothing else in the app writes a path or a URL.
library;

/// The Ninzo rider API.
///
/// Contract: https://mock-server-production-6a71.up.railway.app/contracts/rider.openapi.yaml
/// (readable docs: https://mock-server-production-6a71.up.railway.app/docs/rider). The base URL
/// is `STAGING_API_URL` in `.env`; paths here are relative to it (it ends in `/v1`).
abstract final class RiderApiEndpoints {
  // ── Sign-in ──
  static const otpRequest = '/auth/otp/request';
  static const otpVerify = '/auth/otp/verify';
  static const refresh = '/auth/refresh';
  static const signOut = '/auth/signout';

  // ── Rider ──
  static const me = '/riders/me';
  static const state = '/riders/me/state';
  static const devices = '/riders/me/devices';
  static String device(String deviceId) => '/riders/me/devices/$deviceId';
  static const verification = '/riders/me/verification';
  static const verificationStart = '/riders/me/verification/start';
  static const earnings = '/riders/me/earnings';
  static const problems = '/riders/me/problems';
  static const events = '/riders/me/events';
  static const location = '/riders/me/location';
  static const stream = '/riders/me/stream';
  static const notifications = '/riders/me/notifications';
  static const settings = '/riders/me/settings';
  static const help = '/riders/me/help';
  static const feedback = '/riders/me/feedback';
  static const shiftPlan = '/riders/me/shift-plan';
  static const shiftPlanReply = '/riders/me/shift-plan/reply';

  // ── Shift and spots ──
  static const nodes = '/nodes';
  static const shiftStart = '/riders/me/shifts/start';
  static const shiftEnd = '/riders/me/shifts/end';
  static const shifts = '/riders/me/shifts';
  static const shiftOnline = '/riders/me/shifts/online';
  static const shiftBreak = '/riders/me/shifts/break';
  static const shiftBreakEnd = '/riders/me/shifts/break/end';
  static const shiftPlannedEnd = '/riders/me/shifts/planned-end';
  static const documents = '/riders/me/documents';
  static String acceptRelocation(String relocationId) => '/riders/me/relocations/$relocationId/accept';

  // ── Stock ──
  static const stock = '/riders/me/stock';
  static const stockScan = '/riders/me/stock/scan';
  static String quarantineLot(String lotId) => '/riders/me/stock/$lotId/quarantine';

  // ── Offers and orders ──
  static const offers = '/riders/me/offers';
  static String acceptOffer(String offerId) => '/offers/$offerId/accept';
  static String declineOffer(String offerId) => '/offers/$offerId/decline';
  static String markReady(String offerId) => '/offers/$offerId/ready';
  static String order(String orderId) => '/orders/$orderId';
  static String orderRoute(String orderId) => '/orders/$orderId/route';
  static String orderCall(String orderId) => '/orders/$orderId/call';
  static String handover(String orderId) => '/orders/$orderId/handover';
  static String gateCheck(String orderId) => '/orders/$orderId/gate-check';

  // ── Restock ──
  static const restock = '/restock';
  static const restockOptions = '/restock/options';
  static const restockSuggestions = '/riders/me/restock-suggestions';
  static String restockRequest(String requestId) => '/restock/$requestId';
  static String confirmRestock(String requestId) => '/restock/$requestId/confirm';
  static String declineRestock(String requestId) => '/restock/$requestId/decline';
  static String restockShortfallResponse(String requestId) => '/restock/$requestId/shortfall-response';
}

/// Google and the phone's dialer.
abstract final class ApiEndpoints {
  static const telScheme = 'tel';
  static const directionsHost = 'www.google.com';
  static const directionsPath = '/maps/dir/';
  static const directionsApiParam = 'api';
  static const directionsApiVersion = '1';
  static const directionsDestinationParam = 'destination';

  /// Google Places (New) and Geocoding.
  static const placesAutocomplete = 'https://places.googleapis.com/v1/places:autocomplete';
  static String placeDetails(String id) => 'https://places.googleapis.com/v1/places/$id';
  static const geocode = 'https://maps.googleapis.com/maps/api/geocode/json';
  static const routes = 'https://routes.googleapis.com/directions/v2:computeRoutes';
}
