enum GoOnlineResult {
  /// No stock scanned: Shift 51 "Stock empty".
  needsStock,

  /// Going online needs signal.
  noSignal,

  /// Stock loaded: head to the spot (Shift 19).
  headToSpot,
}
