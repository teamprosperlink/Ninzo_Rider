/// Phone permissions the rider is asked for during onboarding, in order.
enum AppPermission { location, notifications, camera }

/// Outcome of checking or requesting an [AppPermission].
enum PermissionResult {
  granted,

  /// Refused this time; can be asked again.
  denied,

  /// Refused for good; only the phone's settings can change it.
  blocked,

  /// Location services are switched off on the phone.
  serviceOff;

  bool get isGranted => this == granted;
}
