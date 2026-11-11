import '../entities/home_status.dart';
import '../entities/shift.dart';

/// Which Home state (Shift 01–09) the rider sees.
///
/// Before Start riding it follows the stock request: not requested (01),
/// not working today (02), hub preparing before the shift (03), packed
/// before the shift (04), and once the shift has begun (05). After that it follows the phase: heading to or
/// at the hub (07), scanning (08), loaded (09). After the shift's summary it's
/// Shift 05 again (Shift 50 "Done").
class HomeStatusOf {
  const HomeStatusOf();

  HomeStatus call(Shift shift, DateTime now, {bool starting = false}) {
    if (starting) return HomeStatus.starting;
    return switch (shift.phase) {
      ShiftPhase.notStarted => switch (shift.stockRequest) {
        StockRequestStatus.notRequested || StockRequestStatus.awaitingReply => HomeStatus.stockNotRequested,
        StockRequestStatus.notWorkingToday => HomeStatus.offToday,
        // Still packing when the shift begins: start anyway and wait at the
        // hub (Shift 53).
        StockRequestStatus.requested ||
        StockRequestStatus.packing => shift.hasStarted(now) ? HomeStatus.startRiding : HomeStatus.hubPreparing,
        StockRequestStatus.ready => shift.hasStarted(now) ? HomeStatus.startRiding : HomeStatus.stockReady,
      },
      // Backed out of the checklist: start again.
      ShiftPhase.checklist => HomeStatus.startRiding,
      ShiftPhase.headingToHub || ShiftPhase.atHub => HomeStatus.collectStock,
      ShiftPhase.scanning => HomeStatus.finishScanning,
      // Home only shows from Shift 19 once the rider heads to the spot.
      ShiftPhase.stockLoaded || ShiftPhase.headingToSpot || ShiftPhase.online => HomeStatus.stockLoaded,
      ShiftPhase.ended => HomeStatus.startRiding,
    };
  }
}
