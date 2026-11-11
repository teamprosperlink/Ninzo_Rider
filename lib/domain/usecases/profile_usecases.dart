import '../../core/utils/time_format.dart';
import '../entities/rider_application.dart';
import '../entities/rider_document.dart';
import '../entities/shift.dart';
import '../entities/profile.dart';
import '../repositories/profile_repository.dart';
import '../../core/constants/app_patterns.dart';
import '../../core/constants/app_strings.dart';

class WatchProfileFacts {
  const WatchProfileFacts(this._repository);

  final ProfileRepository _repository;

  Stream<ProfileFacts> call(String uid) => _repository.watchFacts(uid);
}

/// Newest first.
class WatchRiderNotifications {
  const WatchRiderNotifications(this._repository);

  final ProfileRepository _repository;

  Stream<List<RiderNotification>> call(String uid) => _repository.watchNotifications(uid);
}

/// Newest first.
class WatchShiftRecords {
  const WatchShiftRecords(this._repository);

  final ProfileRepository _repository;

  Stream<List<ShiftRecord>> call(String uid) => _repository.watchShifts(uid);
}

/// "Hub 2 Yelahanka".
String hubLine(Hub hub) => '${hub.name} ${hub.area}';

/// "+919876543210" as Profile 07 masks it: "+91 98•••• ••210". Figma's mask has
/// one symbol more than a 10-digit number; it's kept as drawn.
String maskedMobile(String e164) {
  final m = RegExp(AppPatterns.indianMobile).firstMatch(e164);
  return m == null ? e164 : AppStrings.indiaPhoneMasked(m[1], m[2]);
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today, 9:12 AM", "Yesterday", then the weekday: "Mon" (Profile 04, 05).
String whenLabel(DateTime at, DateTime now) {
  if (_sameDay(at, now)) return AppStrings.today(clockTime(at));
  if (_sameDay(at, DateTime(now.year, now.month, now.day - 1))) return AppStrings.yesterday2;
  return shortWeekday(at);
}

/// "Today", then "Mon, 2 Nov" (Profile 06).
String shiftDayLabel(DateTime date, DateTime now) => _sameDay(date, now) ? AppStrings.today2 : weekdayDayMonth(date);

/// Shifts the rider rode in the last 7 days, today included (Profile 06). A
/// shift they never went online for isn't one they rode.
List<ShiftRecord> shiftsInLastSevenDays(List<ShiftRecord> records, DateTime now) {
  final first = DateTime(now.year, now.month, now.day - 6);
  return [
    for (final record in records)
      if (record.onlineAt != null && !record.date.isBefore(first)) record,
  ];
}

/// Time online: to the end of the shift, or to now while it runs.
Duration onlineTimeOf(ShiftRecord record, DateTime now) {
  final from = record.onlineAt;
  if (from == null) return Duration.zero;
  final to = record.endedAt ?? (now.isBefore(record.plannedEnd) ? now : record.plannedEnd);
  return to.isBefore(from) ? Duration.zero : to.difference(from);
}

/// The three documents Profile 08 lists, of the five the rider added. The
/// frame has only the "Verified" chip; an approved rider's documents passed
/// review.
List<ProfileDocument> profileDocumentsOf(RiderApplication? application) {
  bool verified(RiderDocument document) =>
      application != null && application.isApproved && application.documents[document]?.issue == null;
  return [
    ProfileDocument(label: AppStrings.drivingLicence, verified: verified(RiderDocument.drivingLicence)),
    ProfileDocument(label: AppStrings.idProof, verified: verified(RiderDocument.aadhaar)),
    ProfileDocument(label: AppStrings.selfie, verified: verified(RiderDocument.selfie)),
  ];
}
