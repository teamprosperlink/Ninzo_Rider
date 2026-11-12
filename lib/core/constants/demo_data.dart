import 'package:latlong2/latlong.dart';

import '../../domain/entities/delivery_order.dart';
import 'app_strings.dart';
import '../../domain/entities/online_status.dart';
import '../../domain/entities/shift_push.dart';
import '../../domain/entities/shift.dart';

/// Sample values used by the demo repositories (`--dart-define=DEMO=true`).
/// They match the Figma placeholders.
abstract final class DemoData {
  /// The "orders are waiting elsewhere" sample on the map.
  static const sampleNudge = RelocationNudge(
    spot: Spot(name: nudgeSpotName, point: LatLng(nudgeSpotLat, nudgeSpotLng)),
    ordersWaiting: nudgeOrders,
    meters: nudgeMeters,
    rideMinutes: nudgeRideMinutes,
  );

  /// What the push pill on Profile sends, in turn.
  static const pushes = [
    (ShiftPush.spotAssigned, AppStrings.spotAssigned),
    (ShiftPush.shiftEndingSoon, AppStrings.shiftEnding),
    (ShiftPush.ordersWaiting, AppStrings.ordersWaiting),
    (ShiftPush.awayFromSpot, AppStrings.awayFromSpot),
  ];

  /// Any 10-digit number signs in with this code.
  static const otp = '123456';

  /// Signing in with this number shows "Account on hold" (Login 16).
  static const onHoldNumber = '9999999999';

  /// This number has no rider account: "Not registered" (Login 03). It
  /// registers as a new rider and is approved after review.
  static const unregisteredNumber = '9000000000';

  /// New riders registering with these numbers get the other review results
  /// (Register 11, 12, 13). Fixing and resubmitting is then approved.
  static const retakeNumber = '9000000001';
  static const failedNumber = '9000000002';
  static const expiredNumber = '9000000003';

  /// How long the demo review team takes (Register 08 → result).
  static const reviewDelay = Duration(seconds: 8);

  /// Codes expire after this long (Login 11).
  static const codeLifetime = Duration(minutes: 5);

  /// Wrong codes allowed before sign-in pauses (Login 10).
  static const maxWrongCodes = 5;

  /// The demo backend's sign-in pause, sent as Retry-After.
  static const signInPause = Duration(minutes: 30);

  static const riderName = 'Ravi Kumar';
  static const riderSinceYear = 2026, riderSinceMonth = 10;
  static const spotAssignedHour = 9, spotAssignedMinute = 12;
  static const hubManagerPhone = '+911140000000';

  /// Profile 05: (title, body, days ago).
  static const notifications = [
    ('Spot assigned · Yelahanka Node', 'Head there when you’re ready to ride.', 0),
    ('Welcome to Ninzo', 'Your account is approved. Finish the pre-shift checks to start.', 1),
    ('Orders waiting at Jakkur Node', 'Your ride there is paid time. Orders reach you when you arrive.', 2),
  ];

  /// Profile 06: (days ago, orders, minutes online, earned).
  static const pastShifts = [
    (0, 9, 252, 360.0),
    (1, 11, 340, 445.0),
    (2, 8, 245, 330.0),
    (3, 12, 370, 470.0),
  ];
  static const hubLabel = 'Hub 2 · Yelahanka';
  static const shiftStart = '11:00 AM';
  static const firstShift = 'Tomorrow, 11:00 AM – 3:00 PM';
  static const spotName = 'Yelahanka Node';
  static const spotDistanceKm = 1.2;

  // ── Today's shift (Figma Sections 4–7) ──

  /// The demo shift starts this long after the app opens, so "Your stock is
  /// ready" (Shift 04) turns into "You're offline · Start riding" (05).
  static const shiftStartsIn = Duration(minutes: 3);
  static const shiftLength = Duration(hours: 4);

  /// Notification 05 "Shift starts at …" and, with no reply, Notification 06,
  /// after the app opens (instead of 1 h and 30 min before the shift).
  static const askPushAfter = Duration(seconds: 5);
  static const reminderPushAfter = Duration(seconds: 35);

  /// After "I'm coming": the hub accepts, then packs (Shift 03 → 04 and
  /// Notification 07).
  static const hubAcceptsAfter = Duration(seconds: 3);
  static const hubPacking = Duration(seconds: 45);

  /// Ride to the hub (Shift 52 → 53 or the stock).
  static const tripToHub = Duration(seconds: 8);

  static const hubId = 'hub-2';
  static const hubName = 'Hub 2';
  static const hubArea = 'Yelahanka';
  static const hubLat = 13.1007, hubLng = 77.5963;
  static const spotLat = 13.1052, spotLng = 77.5921;

  /// Where the demo rider is while heading to the hub, about 1.2 km away.
  static const riderLat = 13.0928, riderLng = 77.5895;
  static const hubDistanceKm = 1.2;
  static const scooterPlate = 'KA 01 AB 1234';
  static const scooterBattery = 82;

  /// What the hub packs: 4 items, 6 portions.
  static const stockItems = 4, stockPortions = 6;

  // ── Go online at spot and online (Figma Sections 9–10) ──

  /// Where the simulated rider is, from the spot: starts 1.2 km away, then
  /// "Almost there", then at the spot.
  static const riderStartMeters = 1200.0, riderAlmostMeters = 240.0, riderAtSpotMeters = 30.0;

  /// Compass direction from the spot to the rider (down-left, as on Shift 21).
  static const riderBearing = 218.66;

  /// Each leg of the ride to the spot (Shift 21 → 22 → 23).
  static const rideLeg = Duration(seconds: 6);
  static const riderAwayMeters = 180.0;
  static const addingTime = Duration(seconds: 1);
  static const orderEarns = 40.0;
  static const lowBattery = 15;

  /// `--dart-define=DEMO_REVA=true`: a first order at Reva Circle, about 5 km
  /// from the spot. Off by default, so the demo keeps the Figma samples.
  static const revaOrder = bool.fromEnvironment('DEMO_REVA');

  /// REVA University, Kattigenahalli; the closest published point to Reva Circle.
  static const revaLat = 13.116833, revaLng = 77.636250;

  /// Assigned at the spot (number, gate, items, cash to collect).
  static const List<(String, String, int, int?)> orderQueue = [
    if (revaOrder) ('A2942', 'Reva Circle', 2, null),
    ('A2931', 'Gate 3', 2, null),
    ('A2934', 'Gate 5', 1, 149),
    ('A2936', 'Gate 1', 3, null),
    ('A2938', 'Gate 7', 2, null),
    ('A2940', 'Gate 2', 1, 99),
  ];

  // ── Refill, restock, move to a new spot, break (Figma Sections 16–19) ──

  /// Refill 01's sample.
  static const refillOrders = 9, refillEarned = 360.0;
  static const List<(String, int)> itemsLeftSample = [
    ('Smash Burger', 0),
    ('Paneer Tikka Wrap', 1),
    ('Peri Peri Fries', 0),
  ];

  /// Restock 01, 02.
  static const restockHub = 'Hub 2', restockReadyIn = 12, restockRide = 5;
  static const List<(String, String, int)> restockLines = [
    ('smash-burger', 'Smash Burger', 4),
    ('paneer-tikka-wrap', 'Paneer Tikka Wrap', 0),
  ];

  /// Restock 03.
  static const restockQueueSlot = 3;
  static const restockArriveIn = Duration(minutes: 26), restockPackedIn = Duration(minutes: 9);

  /// Restock 05.
  static const shortCanGive = 2, otherHub = 'Hub 4', otherHubKm = 2.1, otherHubHas = 4;

  /// Shift 36–38.
  static const nudgeSpotName = 'Jakkur Node';
  static const nudgeSpotLat = 13.1095, nudgeSpotLng = 77.5960;
  static const nudgeOrders = 3, nudgeMeters = 450, nudgeRideMinutes = 3;

  // ── Choose a spot (Figma Section 24) ──

  /// Shift 13 and Shift 16 last this long.
  static const findingSpots = Duration(seconds: 3), confirmingSpot = Duration(seconds: 2);

  /// Shift 14: (name, km, taken, capacity, lat, lng).
  static const choiceSpots = [
    ('Jakkur Node', 0.9, 0, 3, nudgeSpotLat, nudgeSpotLng),
    ('Yelahanka Node', 1.2, 1, 3, spotLat, spotLng),
    ('Hebbal Node', 2.4, 3, 3, 13.1188, 77.5788),
  ];

  // ── Connection, end shift, earnings and sync (Figma Sections 20–22) ──

  /// Shift 47's gate; Shift 50's average.
  static const orderPlace = 'Prestige Apts', averageDeliverySeconds = 68;

  /// Shift 46.
  static const chosenShift = Duration(hours: 8);

  /// Earnings 01.
  static const earningsOrders = 9, earningsOrderPay = 320.0, earningsIncentives = 30.0;
  static const earningsRepositionMinutes = 12, earningsRepositionPay = 10.0;

  /// Sync 01: (label, hour, minute), and the last sync.
  static const List<(String, int, int)> syncEvents = [
    ('Arrival · Gate 3', 14, 16),
    ('Handover · #A2931', 14, 17),
    ('Restock confirmed', 14, 18),
  ];
  static const lastSyncHour = 14, lastSyncMinute = 14;

  // ── Order, gate arrival, navigate (Figma Sections 11–13) ──

  /// Order details by number: (gate's landmark, items with quantity, UPI amount).
  static const Map<String, (String, List<(String, int)>, int)> orderDetails = {
    if (revaOrder) 'A2942': ('Kattigenahalli', [('Smash Burger', 1), ('Cold Coffee', 1)], 120),
    'A2931': ('Main entrance', [('Smash Burger', 2), ('Paneer Tikka Wrap', 1)], 60),
    'A2934': ('Service road', [('Cold Coffee', 1)], 149),
    'A2936': ('North entrance', [('Smash Burger', 1), ('Peri Peri Fries', 1), ('Cold Coffee', 1)], 120),
    'A2938': ('East wing', [('Paneer Tikka Wrap', 1), ('Peri Peri Fries', 1)], 89),
    'A2940': ('Market side', [('Cold Coffee', 1)], 99),
  };
  static const customerProxyPhone = '+918000000000';

  /// Where the rider is from the gate on each leg, and in which compass
  /// direction, as drawn on Order 01, 02 and 03.
  static const gateLegMeters = [600.0, 300.0, 100.0];
  static const gateBearings = [141.34, 138.01, 156.8];
  static const gateFromRiderMeters = 600.0;

  /// Arrival 02 and 03.
  static const atGateMeters = 38.0, confirmedAtGateMeters = 12.0;

  /// From 0.3 km to 0.1 km from the gate.
  static const orderRideLeg = Duration(seconds: 20);

  /// A gate's QR code says `NZG|<gate id>`.
  static const gateQr = 'NZG|gate-3', wrongGateQr = 'NZG|gate-9', gateCode = '4821';

  /// What the "Customer cancels" pill plays: Navigate 04, 05, 06.
  /// The demo's help centre (the rider API's comes from `help_articles`).
  static const List<(String, String)> helpArticles = [
    (AppStrings.howDoIGoOnline, 'Finish the checklist, ride to your hub, scan your stock, then ride to your spot.'),
    (AppStrings.howDoILoadStockAt, 'When the hub has packed your stock, scan each lot’s code on the stock screen.'),
    (AppStrings.customerIsnTAtTheGate, 'Wait at the gate, then use Report a problem and choose Customer absent.'),
    (AppStrings.howAreMyEarningsCounted, 'You earn for each order handed over, an incentive at the day’s target, and paid moves.'),
    (AppStrings.howDoIChangeMyShift, 'Use Add time to ride longer today, or call your hub manager.'),
    (AppStrings.scooterHasAFaultWhoDo, 'Use Report a problem and choose Breakdown, then call your hub manager.'),
  ];

  static const List<(OrderPayment, int)> cancellations = [
    (OrderPayment.upi, 60),
    (OrderPayment.cash, 149),
    (OrderPayment.upi, 16),
  ];

  /// What the demo's backend pays for a cancellation (Navigate 04–06): UPI the
  /// lesser of ₹20 and the order's price, cash nothing.
  static int cancellationPay(OrderPayment payment, int amount) =>
      payment == OrderPayment.cash ? 0 : (amount < _upiCancellationPay ? amount : _upiCancellationPay);
  static const _upiCancellationPay = 20;

  // ── Handover and problem report (Figma Sections 14–15) ──

  /// The customer's code on every demo UPI order. The rider never sees the
  /// real one: the backend checks it. 4821 plays Handover 04.
  static const deliveryCode = '4829';

  /// How long "Confirming…" (Handover 05) and sending a report take.
  static const codeCheck = Duration(milliseconds: 900), reportSending = Duration(milliseconds: 500);

  // ── Stock scan (Figma Section 8) ──

  /// (id, name, portions, photo) of the load.
  static const stockList = [
    ('smash-burger', 'Smash Burger', 2, 'assets/images/stock_smash_burger.jpg'),
    ('paneer-tikka-wrap', 'Paneer Tikka Wrap', 2, 'assets/images/stock_paneer_tikka_wrap.jpg'),
    ('peri-peri-fries', 'Peri Peri Fries', 1, 'assets/images/stock_peri_peri_fries.jpg'),
    ('cold-coffee', 'Cold Coffee', 1, 'assets/images/stock_cold_coffee.jpg'),
  ];

  static const goodLot = 'A-1100', expiredLot = 'B-2207', warmLot = 'B-2209';
  static const lotLife = Duration(hours: 6);

  /// How long "Checking item…" (Stock 12) stays up.
  static const lotCheck = Duration(milliseconds: 900);

  /// What each tap on the viewfinder "scans", in order: every outcome, ending
  /// with all 6 portions loaded.
  static const scanScript = [
    'NZ1|smash-burger|A-1100|1', // Stock 02: 1 of 6
    'NZ1|smash-burger|B-2207|9', // Stock 07: expired lot
    'NZ1|smash-burger|A-1100|2', // Stock 02: 2 of 6
    'NZ1|smash-burger|A-1100|2', // Stock 10: already scanned
    'NZ1|smash-burger|A-1100|3', // Stock 11: more than today's load
    'NZ1|masala-dosa|A-1100|1', // Stock 04: not on list
    'NZ1|paneer-tikka-wrap|B-2209|9', // Stock 08: too warm
    'NZ1|paneer-tikka-wrap|A-1100|1', // Stock 02: 3 of 6
    'NZ1|paneer-tikka-wrap|A-1100|2',
    'NZ1|peri-peri-fries|A-1100|1',
    'NZ1|cold-coffee|A-1100|1', // the last: Stock 15, or 14 without signal
  ];

  /// (id, name, popular, lat, lng) of the sample areas (Register 14–15).
  static const areas = [
    ('yelahanka', 'Yelahanka', true, 13.1007, 77.5963),
    ('bagalur', 'Bagalur', true, 13.1333, 77.6667),
    ('jakkur', 'Jakkur', true, 13.0786, 77.6060),
    ('hebbal', 'Hebbal', true, 13.0358, 77.5970),
    ('devanahalli', 'Devanahalli', true, 13.2437, 77.7172),
    ('kogilu', 'Kogilu', true, 13.1046, 77.6150),
    ('yelahanka-new-town', 'Yelahanka New Town', false, 13.1004, 77.5770),
    ('yelahanka-old-town', 'Yelahanka Old Town', false, 13.0950, 77.5960),
    ('yelahanka-satellite-town', 'Yelahanka Satellite Town', false, 13.0840, 77.5850),
  ];
  static const city = 'Bengaluru';

  static const _newRiderNumbers = [unregisteredNumber, retakeNumber, failedNumber, expiredNumber];

  /// Numbers registered while the demo runs (E.164).
  static final _registered = <String>{};

  /// Demo uid for a phone number in E.164 form.
  static String uidFor(String phoneNumber) => 'demo-${phoneNumber.replaceAll('+', '')}';

  /// Phone number (E.164) of a demo uid.
  static String phoneFor(String uid) => '+${uid.replaceFirst('demo-', '')}';

  /// Whether [phoneNumber] (E.164) belongs to a sample rider, or registered
  /// while the demo runs.
  static bool isRegistered(String phoneNumber) => _registered.contains(phoneNumber) || !isNewRider(phoneNumber);

  /// One of the numbers that register as a new rider.
  static bool isNewRider(String phoneNumber) => _newRiderNumbers.any(phoneNumber.endsWith);

  static void markRegistered(String phoneNumber) => _registered.add(phoneNumber);
}
