/// What the rider directory knows about a phone number before sign-in.
class RiderAccountInfo {
  const RiderAccountInfo({this.onHold = false, this.hubLabel, this.shiftStart});

  /// The account is paused by operations (Login 16).
  final bool onHold;

  /// e.g. "Hub 2 · Yelahanka".
  final String? hubLabel;

  /// e.g. "11:00 AM".
  final String? shiftStart;

  /// "Your shift at Hub 2 · Yelahanka starts at 11:00 AM." when both are known.
  String? get shiftSummary =>
      hubLabel != null && shiftStart != null ? 'Your shift at $hubLabel starts at $shiftStart.' : null;
}
