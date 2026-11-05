import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../../core/config/demo_data.dart';
import '../../domain/entities/shift.dart';
import '../../domain/repositories/shift_repository.dart';
import '../../domain/usecases/plan_shift_pushes.dart';

/// In-memory shift for demo mode, driving the day with short delays (see
/// [DemoData]): the shift starts [DemoData.shiftStartsIn] after the app
/// opens; "I'm coming" is accepted after [DemoData.hubAcceptsAfter] and
/// packed after [DemoData.hubPacking]; the ride to the hub takes
/// [DemoData.tripToHub].
class DemoShiftRepository implements ShiftRepository {
  DemoShiftRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    final now = _clock();
    final start = DateTime(now.year, now.month, now.day, now.hour, now.minute + 1).add(DemoData.shiftStartsIn);
    _template = Shift(
      id: Shift.idFor(now),
      start: start,
      end: start.add(DemoData.shiftLength),
      hub: const Hub(
        id: DemoData.hubId,
        name: DemoData.hubName,
        area: DemoData.hubArea,
        point: LatLng(DemoData.hubLat, DemoData.hubLng),
        managerPhone: DemoData.hubManagerPhone,
      ),
      spot: const Spot(name: DemoData.spotName, point: LatLng(DemoData.spotLat, DemoData.spotLng)),
      scooter: const Scooter(plate: DemoData.scooterPlate, batteryPercent: DemoData.scooterBattery),
      stock: const StockLoad(items: DemoData.stockItems, portions: DemoData.stockPortions),
      hubDistanceKm: DemoData.hubDistanceKm,
    );
    opened = now;
  }

  final DateTime Function() _clock;
  late final Shift _template;

  /// When the demo started; the pushes are timed from here.
  late final DateTime opened;

  final _shifts = <String, Shift>{};
  final _changes = StreamController<String>.broadcast();
  final _timers = <Timer>[];

  Shift _get(String uid) => _shifts[uid] ??= _template;

  void _put(String uid, Shift shift) {
    _shifts[uid] = shift;
    _changes.add(uid);
  }

  void _after(Duration delay, void Function() action) => _timers.add(Timer(delay, action));

  @override
  Stream<Shift?> watchToday(String uid) async* {
    yield _get(uid);
    yield* _changes.stream.where((id) => id == uid).map((_) => _get(uid));
  }

  @override
  Future<void> replyToStockRequest(String uid, String shiftId, StockRequestStatus reply) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _put(uid, _get(uid).copyWith(stockRequest: reply));
    if (reply != StockRequestStatus.requested) return;
    // The hub accepts, then packs.
    _after(DemoData.hubAcceptsAfter, () {
      if (_get(uid).stockRequest != StockRequestStatus.requested) return;
      _put(
        uid,
        _get(uid)
            .copyWith(stockRequest: StockRequestStatus.packing, stockReadyAt: () => _clock().add(DemoData.hubPacking)),
      );
      _after(DemoData.hubPacking, () => _put(uid, _get(uid).copyWith(stockRequest: StockRequestStatus.ready)));
    });
  }

  @override
  Future<void> setPhase(String uid, String shiftId, ShiftPhase phase) async {
    await Future<void>.delayed(Duration(milliseconds: phase == ShiftPhase.checklist ? 1200 : 300));
    _put(uid, _get(uid).copyWith(phase: phase));
    if (phase == ShiftPhase.headingToHub) {
      _after(DemoData.tripToHub, () {
        if (_get(uid).phase == ShiftPhase.headingToHub) _put(uid, _get(uid).copyWith(phase: ShiftPhase.atHub));
      });
    }
  }

  @override
  Future<void> setRefill(
    String uid,
    String shiftId, {
    required RefillLoad? refill,
    required int round,
    required ShiftPhase phase,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _put(uid, _get(uid).copyWith(refill: () => refill, refillRound: round, phase: phase));
  }

  @override
  Future<void> setSpot(String uid, String shiftId, Spot spot) async => _put(uid, _get(uid).copyWith(spot: spot));

  @override
  Future<void> recordScans(String uid, String shiftId, int scanned) async {
    final shift = _get(uid);
    _put(uid, shift.copyWith(stock: shift.stock.copyWith(scanned: scanned)));
  }

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
  }
}

/// Demo push times: Notification 05 a few seconds after the app opens and
/// the reminder half a minute later.
class DemoPushTimes implements PushTimes {
  const DemoPushTimes(this.opened);

  final DateTime opened;

  @override
  DateTime askAt(Shift shift) => opened.add(DemoData.askPushAfter);

  @override
  DateTime reminderAt(Shift shift) => opened.add(DemoData.reminderPushAfter);
}
