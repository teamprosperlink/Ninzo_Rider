/// Which refill screen takes over from the main map.
enum RefillPrompt {
  none,

  /// Refill 01.
  lowStock,

  /// Refill 02: new orders are paused.
  outOfStock,
}
