/// A town, junction or city a rider can choose as their area (Register
/// 14–16). The backend maps the area to a hub; riders never pick a hub or
/// spot themselves.
class RiderArea {
  const RiderArea({
    required this.id,
    required this.name,
    required this.city,
    this.latitude,
    this.longitude,
    this.popular = false,
  });

  final String id;

  /// e.g. "Yelahanka".
  final String name;

  /// e.g. "Bengaluru".
  final String city;
  final double? latitude;
  final double? longitude;

  /// Shown before the rider types anything.
  final bool popular;

  @override
  bool operator ==(Object other) => other is RiderArea && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
