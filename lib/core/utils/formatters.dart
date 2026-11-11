import 'package:flutter/services.dart';
import '../constants/app_strings.dart';

String rupees(double amount) => AppStrings.rupeeAmount(amount.toStringAsFixed(0));

/// "350 m" below a kilometre, "1.2 km" above.
String distance(double km) => km < 1 ? AppStrings.textM((km * 1000).round()) : AppStrings.textKm(km.toStringAsFixed(1));

/// In kilometres, as on the order screens ("0.3 km"), until that would say
/// 0.0 km ("38 m").
String kilometres(double meters) =>
    meters < 50 ? AppStrings.textM(meters.round()) : AppStrings.textKm((meters / 1000).toStringAsFixed(1));

/// Whole seconds as "02:14".
String minutesSeconds(int seconds) {
  final s = seconds.abs();
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "1st", "2nd", "3rd", "4th" (Restock 03).
String ordinal(int n) {
  final tens = n % 100;
  if (tens >= 11 && tens <= 13) return AppStrings.textTh(n);
  return switch (n % 10) {
    1 => AppStrings.textSt(n),
    2 => AppStrings.textNd(n),
    3 => AppStrings.textRd(n),
    _ => AppStrings.textTh(n),
  };
}

/// Whole seconds as "1:05".
String clock(int seconds) {
  final s = seconds.abs();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "+919876543210" as "+91 98765 43210"; other numbers unchanged.
String phoneNumber(String e164) {
  final m = RegExp(r'^\+91(\d{5})(\d{5})$').firstMatch(e164);
  return m == null ? e164 : AppStrings.indiaPhoneSpaced(m[1], m[2]);
}

/// "1 delivery", "3 deliveries".
String plural(int count, String one, String many) => '$count ${count == 1 ? one : many}';

/// The turn button: "Turn right (2.4 km)". Without a routing service there's
/// no turn, so just what's known.
String turnButtonLabel(String? maneuver, String away) {
  final turn = maneuver ?? '';
  if (turn.isEmpty) return away;
  return away.isEmpty ? turn : '$turn ($away)';
}

/// Phone digits shown as "98765 43210".
String formatPhoneDigits(String digits) =>
    digits.length <= 5 ? digits : '${digits.substring(0, 5)} ${digits.substring(5)}';

/// Digits only, at most 10, shown as "98765 43210".
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);
    final text = formatPhoneDigits(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
