import '../entities/shift.dart';
import '../entities/shift_push.dart';
import 'plan_shift_pushes.dart';
import '../entities/online_status.dart';
import 'online_usecases.dart';
import 'spot_usecases.dart';

/// Notification 01–04, from what the phone can see for itself.
///
/// With the rider API the server sends all but "away from your spot" itself,
/// so they reach a rider whose app is closed; the app drops those
/// (`WatchServerPushes.withoutServerSent`). Demo mode shows them all.
class PlanOnlinePushes {
  const PlanOnlinePushes();

  /// After a change to the shift or the backend's status.
  PushPlan call(
    Shift shift,
    OnlineStatus status,
    DateTime now, {
    Shift? previousShift,
    OnlineStatus? previous,
  }) {
    final at = shiftEndOf(shift, status).subtract(SelectOnlineAlert.endingWindow);
    final ending = shift.phase == ShiftPhase.online && at.isAfter(now.subtract(PlanShiftPushes.grace));
    final spotChanged =
        previousShift != null &&
        previousShift.id == shift.id &&
        previousShift.spot.name != shift.spot.name &&
        // The rider chose this one by taking the nudge.
        status.nudge == null;
    final nudged = status.nudge?.stage == NudgeStage.offered && previous?.nudge?.stage != NudgeStage.offered;
    return PushPlan(
      schedule: {if (ending) ShiftPush.shiftEndingSoon: at},
      cancel: {if (!ending) ShiftPush.shiftEndingSoon},
      showNow: {if (spotChanged) ShiftPush.spotAssigned, if (nudged) ShiftPush.ordersWaiting},
      detail: PushDetail(spotName: status.nudge?.spot.name ?? ''),
    );
  }

  /// After the rider moves: Notification 04 when they've just left the spot.
  PushPlan onPosition(Shift shift, OnlineStatus status, double? previousMeters, double meters) {
    final left =
        shift.phase == ShiftPhase.online &&
        status.activeOrderId == null &&
        SpotRules.isAway(meters) &&
        (previousMeters == null || !SpotRules.isAway(previousMeters));
    return PushPlan(showNow: {if (left) ShiftPush.awayFromSpot}, detail: PushDetail(metersFromSpot: meters));
  }
}
