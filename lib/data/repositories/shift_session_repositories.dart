import '../../domain/repositories/shift_end_repositories.dart';

/// The demo's other phone, which the Home pill opens the shift on.
class DemoShiftSessionRepository implements ShiftSessionRepository {
  bool otherPhone = false;

  @override
  Future<bool> openElsewhere(String uid, String shiftId) async => otherPhone;

  @override
  Future<void> claim(String uid, String shiftId) async => otherPhone = false;

  @override
  Future<void> markEnded(String uid, String shiftId) async {}
}
