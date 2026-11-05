/// The next instruction on the way to a place.
class RouteStep {
  const RouteStep({required this.instruction, this.street, required this.maneuver, required this.totalKm});

  /// "In 120 m, turn right".
  final String instruction;

  /// "Onto 2nd Cross".
  final String? street;

  /// Short form for the button: "Turn right".
  final String maneuver;

  /// Distance left to the destination.
  final double totalKm;

  /// Which way the arrow points.
  bool get turnsLeft => maneuver.toLowerCase().contains('left');
}
