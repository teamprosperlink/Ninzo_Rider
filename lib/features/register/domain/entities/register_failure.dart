/// Why a registration step failed. Only [alreadyRegistered] shows (Register 03).
enum RegisterFailureKind {
  /// Register 03: the number already has a rider account.
  alreadyRegistered,

  /// Fewer than 10 digits or not an Indian mobile number.
  invalidNumber,

  /// Location is off or not allowed ("Use my current location").
  locationUnavailable,

  /// No area near the rider's position.
  noAreaNearby,

  /// Camera permission denied.
  cameraDenied,

  noInternet,
  unknown,
}

class RegisterFailure implements Exception {
  const RegisterFailure(this.kind, [this.message]);

  final RegisterFailureKind kind;
  final String? message;

  @override
  String toString() => message ?? kind.name;
}
