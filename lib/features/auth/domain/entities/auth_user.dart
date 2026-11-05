class AuthUser {
  const AuthUser({required this.uid, required this.phone});

  final String uid;

  /// E.164 format, e.g. +919876543210.
  final String phone;
}
