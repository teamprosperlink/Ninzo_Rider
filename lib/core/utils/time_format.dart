/// Pure-Dart time and date formatting used by domain text (pushes) and
/// screens.
library;

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "9:00 AM", "12:30 PM".
String clockTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "2:14 pm" (Stock 07, 13).
String lowerClockTime(DateTime t) => clockTime(t).toLowerCase();

/// "9:41" (lock-screen clock, 12-hour without AM/PM).
String shortClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')}';
}

/// "7h 52m" (Shift 46, 48, 50).
String hoursAndMinutes(Duration d) => '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';

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
    ? 'Good morning'
    : t.hour < 17
    ? 'Good afternoon'
    : 'Good evening';
