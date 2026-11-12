import '../../core/utils/time_format.dart';
import 'rider_settings.dart';
import 'shift.dart';
import '../../core/constants/app_strings.dart';

/// The shift's push notifications (Figma "Section · 4 · Morning stock
/// request · push" and "Section · 26 · Other push notifications").
enum ShiftPush {
  /// Notification 05, 1 hour before the shift: confirm you're coming.
  prepareStock(501),

  /// Notification 06, 30 minutes before, when there was no reply.
  reminder(502),

  /// Notification 07: the hub has packed the stock.
  stockReady(503),

  /// Notification 01: tap → Profile 04.
  spotAssigned(504),

  /// Notification 02, 15 minutes before the end: tap → Shift 32.
  shiftEndingSoon(505),

  /// Notification 03: tap → Shift 05.
  ordersWaiting(506),

  /// Notification 04: tap → Shift 30.
  awayFromSpot(507);

  const ShiftPush(this.id);

  /// Notification id on the device.
  final int id;

  /// Asks the rider to reply.
  bool get hasActions => this == prepareStock || this == reminder;

  /// The pushes the rider API sends itself (FCM), so the phone doesn't
  /// schedule them. The stock request, with its replies, and "away from your
  /// spot", which only the phone's GPS knows, stay the phone's.
  static const fromServer = {stockReady, spotAssigned, shiftEndingSoon, ordersWaiting};

  /// The push for a rider API notification's `notification_kind`, if the
  /// phone shows it.
  static ShiftPush? ofServerKind(String? kind) => switch (kind) {
    'stock_ready' => stockReady,
    'spot_assigned' => spotAssigned,
    'shift_ending_soon' => shiftEndingSoon,
    'orders_waiting' => ordersWaiting,
    _ => null,
  };
}

/// What the rider tapped on a push.
enum ShiftPushAction {
  /// "I'm coming": the hub packs the stock.
  coming,

  /// "Not today": nothing is packed.
  notToday,

  /// The notification itself: opens Home.
  open,
}

/// What a push says that the shift doesn't know.
class PushDetail {
  const PushDetail({this.spotName = '', this.metersFromSpot = 0});

  /// Where orders wait (Notification 03).
  final String spotName;

  /// How far the rider is (Notification 04).
  final double metersFromSpot;
}

/// Text of a push, as in the design.
class ShiftPushContent {
  const ShiftPushContent({required this.title, required this.body, this.actions = const {}});

  final String title;
  final String body;

  /// Action buttons in order.
  final Map<ShiftPushAction, String> actions;

  static ShiftPushContent of(ShiftPush push, Shift shift, {PushDetail detail = const PushDetail()}) => switch (push) {
    ShiftPush.prepareStock => ShiftPushContent(
      title: AppStrings.shiftStartsAt(clockTime(shift.start)),
      // Reply before the reminder: the gap between the two, from the rider API.
      body: AppStrings.tellTheHubYouReComing(
        (RiderSettings.current.stockAskBefore - RiderSettings.current.stockReminderBefore).inMinutes,
      ),
      actions: _reply,
    ),
    ShiftPush.reminder => const ShiftPushContent(
      title: AppStrings.hubNeedsToHearFromYou,
      body: AppStrings.withoutAReplyNoStockIs,
      actions: _reply,
    ),
    ShiftPush.stockReady => ShiftPushContent(
      title: AppStrings.yourStockIsReadyAt(shift.hub.name),
      body: AppStrings.startRidingWhenYourShiftBegins,
    ),
    ShiftPush.spotAssigned => ShiftPushContent(
      title: AppStrings.yourSpotIs(shift.spot.name),
      body: AppStrings.headThereWhenYouReReady,
    ),
    ShiftPush.shiftEndingSoon => ShiftPushContent(
      title: AppStrings.yourShiftEndsIn(RiderSettings.current.endingSoonBefore.inMinutes),
      body: AppStrings.addTimeToKeepGettingOrders2,
    ),
    ShiftPush.ordersWaiting => ShiftPushContent(
      title: AppStrings.ordersAreWaitingAt(detail.spotName),
      body: AppStrings.yourRideThereIsPaidTime2,
    ),
    ShiftPush.awayFromSpot => ShiftPushContent(
      title: AppStrings.youReAwayFromYourSpot,
      body: AppStrings.youReMFromHeadBack(detail.metersFromSpot.round(), shift.spot.name),
    ),
  };

  static const _reply = {ShiftPushAction.coming: AppStrings.iMComing, ShiftPushAction.notToday: AppStrings.notToday};
}
