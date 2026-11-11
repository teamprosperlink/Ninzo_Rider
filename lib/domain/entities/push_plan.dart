import 'shift_push.dart';

/// What to do with the pushes after a change to the shift.
class PushPlan {
  const PushPlan({this.schedule = const {}, this.cancel = const {}, this.showNow = const {}, this.detail = const PushDetail()});

  final Map<ShiftPush, DateTime> schedule;
  final Set<ShiftPush> cancel;
  final Set<ShiftPush> showNow;

  /// What [showNow]'s pushes say beyond the shift.
  final PushDetail detail;
}
