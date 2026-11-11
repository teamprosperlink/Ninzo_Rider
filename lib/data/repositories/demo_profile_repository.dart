import '../../core/constants/demo_data.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';

/// The Figma sample values, dated from today.
class DemoProfileRepository implements ProfileRepository {
  DemoProfileRepository(this._clock);

  final DateTime Function() _clock;

  DateTime _day(int daysAgo, [int hour = 0, int minute = 0]) {
    final now = _clock();
    return DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
  }

  @override
  Stream<ProfileFacts> watchFacts(String uid) => Stream.value(
    ProfileFacts(
      riderSince: DateTime(DemoData.riderSinceYear, DemoData.riderSinceMonth),
      spotAssignedAt: _day(0, DemoData.spotAssignedHour, DemoData.spotAssignedMinute),
    ),
  );

  @override
  Stream<List<RiderNotification>> watchNotifications(String uid) => Stream.value([
    for (final (i, (title, body, daysAgo)) in DemoData.notifications.indexed)
      RiderNotification(
        id: '$i',
        title: title,
        body: body,
        at: _day(daysAgo, DemoData.spotAssignedHour, DemoData.spotAssignedMinute),
      ),
  ]);

  @override
  Stream<List<ShiftRecord>> watchShifts(String uid) => Stream.value([
    for (final (daysAgo, orders, minutes, earned) in DemoData.pastShifts)
      ShiftRecord(
        date: _day(daysAgo),
        orders: orders,
        earned: earned,
        onlineAt: _day(daysAgo),
        plannedEnd: _day(daysAgo, 23, 59),
        endedAt: _day(daysAgo).add(Duration(minutes: minutes)),
      ),
  ]);
}
