import '../entities/rider_account_info.dart';

/// Looks up rider accounts by phone number before sign-in.
abstract interface class RiderDirectory {
  /// The account for [phoneNumber] (E.164), or null if there is none.
  /// Throws an [AuthFailure] with [AuthFailureKind.noInternet] when offline.
  Future<RiderAccountInfo?> find(String phoneNumber);
}
