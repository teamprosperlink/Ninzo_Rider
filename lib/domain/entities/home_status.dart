/// What Home shows: each value is one Figma frame of "Section · 5 · Home ·
/// daily states". Worked out from the shift by `HomeStatusOf`.
enum HomeStatus {
  /// Shift 01: the hub hasn't been told the rider is coming.
  stockNotRequested,

  /// Shift 02: the rider said "Not today".
  offToday,

  /// Shift 03: confirmed; the hub is packing.
  hubPreparing,

  /// Shift 04: packed, the shift hasn't started yet.
  stockReady,

  /// Shift 05: the shift has started; Start riding.
  startRiding,

  /// Shift 06: Start riding tapped, waiting for the server.
  starting,

  /// Shift 07: heading to (or at) the hub.
  collectStock,

  /// Shift 08: part of the stock scanned.
  finishScanning,

  /// Shift 09: all stock scanned; Go online.
  stockLoaded,
}
