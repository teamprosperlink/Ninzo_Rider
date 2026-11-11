/// Text formats: what a scan or a typed value has to look like.
abstract final class AppPatterns {
  static const gateQr = r'^NZG\|[\w-]+$';
  static const fourDigitCode = r'^\d{4}$';
  static const indianMobile = r'^\+91(\d{2})\d{5}(\d{3})$';
  static const whitespace = r'\s+';
  static const scanPrefix = 'NZ1';
  static const scanSeparator = '|';
  static const leftTurn = 'left';
  static String scanCode(Object? itemId, Object? lotId, Object? portion) => '$scanPrefix|$itemId|$lotId|$portion';
  static String manualScan(Object? itemId, Object? portion) => 'manual|$itemId|$portion';
}
