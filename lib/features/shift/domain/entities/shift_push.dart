import '../../../../core/utils/time_format.dart';
import 'shift.dart';

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
      title: 'Shift starts at ${clockTime(shift.start)}',
      body: 'Tell the hub you’re coming and they’ll pack your stock. Reply within 30 min.',
      actions: _reply,
    ),
    ShiftPush.reminder => const ShiftPushContent(
      title: 'Hub needs to hear from you',
      body: 'Without a reply, no stock is packed for you. Tap to confirm you’re coming.',
      actions: _reply,
    ),
    ShiftPush.stockReady => ShiftPushContent(
      title: 'Your stock is ready at ${shift.hub.name}',
      body: 'Start riding when your shift begins, then head to the hub to collect it.',
    ),
    ShiftPush.spotAssigned => ShiftPushContent(
      title: 'Your spot is ${shift.spot.name}',
      body: 'Head there when you’re ready to ride. Tap to see the route.',
    ),
    ShiftPush.shiftEndingSoon => const ShiftPushContent(
      title: 'Your shift ends in 15 minutes',
      body: 'Add time to keep getting orders. If you do nothing, your shift ends on time.',
    ),
    ShiftPush.ordersWaiting => ShiftPushContent(
      title: 'Orders are waiting at ${detail.spotName}',
      body: 'Your ride there is paid time. Orders reach you as soon as you arrive.',
    ),
    ShiftPush.awayFromSpot => ShiftPushContent(
      title: 'You’re away from your spot',
      body: 'You’re ${detail.metersFromSpot.round()} m from ${shift.spot.name}. Head back to keep getting orders.',
    ),
  };

  static const _reply = {ShiftPushAction.coming: 'I’m coming', ShiftPushAction.notToday: 'Not today'};
}
