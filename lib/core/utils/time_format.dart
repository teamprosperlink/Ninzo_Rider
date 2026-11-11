/// Pure-Dart time and date formatting used by domain text (pushes) and
/// screens.
library;

import '../constants/app_strings.dart';

const _months = [
  AppStrings.january, AppStrings.february, AppStrings.march, AppStrings.april, AppStrings.may, AppStrings.june, //
  AppStrings.july, AppStrings.august, AppStrings.september, AppStrings.october, AppStrings.november, AppStrings.december,
];
const _weekdays = [AppStrings.monday, AppStrings.tuesday, AppStrings.wednesday, AppStrings.thursday, AppStrings.friday, AppStrings.saturday, AppStrings.sunday];

/// "9:00 AM", "12:30 PM".
String clockTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return AppStrings.clockWithPeriod(h, t.minute.toString().padLeft(2, '0'), t.hour < 12 ? AppStrings.textAm : AppStrings.textPm);
}

/// "2:14 pm" (Stock 07, 13).
String lowerClockTime(DateTime t) => clockTime(t).toLowerCase();

/// "9:41" (lock-screen clock, 12-hour without AM/PM).
String shortClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')}';
}

/// "7h 52m" (Shift 46, 48, 50).
String hoursAndMinutes(Duration d) => AppStrings.textHM(d.inHours, (d.inMinutes % 60).toString().padLeft(2, '0'));

/// A time span as hours and minutes: "0:12" (the Online stat).
String hoursMinutes(Duration d) => '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

/// "Tuesday, 3 November".
String longDate(DateTime t) => '${_weekdays[t.weekday - 1]}, ${t.day} ${_months[t.month - 1]}';

/// "Mon".
String shortWeekday(DateTime t) => _weekdays[t.weekday - 1].substring(0, 3);

/// "Mon, 2 Nov".
String weekdayDayMonth(DateTime t) => '${shortWeekday(t)}, ${t.day} ${_months[t.month - 1].substring(0, 3)}';

/// "Oct 2026".
String monthYear(DateTime t) => '${_months[t.month - 1].substring(0, 3)} ${t.year}';

/// "Good morning" before noon, "Good afternoon" until 5 PM, then "Good evening".
String greeting(DateTime t) => t.hour < 12
    ? AppStrings.goodMorning
    : t.hour < 17
    ? AppStrings.goodAfternoon
    : AppStrings.goodEvening;
