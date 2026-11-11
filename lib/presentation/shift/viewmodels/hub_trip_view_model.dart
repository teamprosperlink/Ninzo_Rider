import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/providers/auth_state_providers.dart';
import '../../../injection_container.dart';
import '../../../domain/entities/shift.dart';
import '../../../domain/entities/route_step.dart';
import '../providers/shift_providers.dart';

class HubTripState {
  const HubTripState({this.position, this.step, this.positionError});

  /// The rider, when known.
  final LatLng? position;

  /// Next turn and distance left.
  final RouteStep? step;
  final Object? positionError;
}

/// Shift 52 "Heading to hub": follows the rider, shows the next turn and
/// marks the arrival when they're within [ArriveAtHub.radiusMeters].
class HubTripViewModel extends Notifier<HubTripState> {
  StreamSubscription<LatLng>? _sub;
  bool _arriving = false;

  @override
  HubTripState build() {
    _sub = ref
        .watch(tripPositionSourceProvider)()
        .listen(
          _onPosition,
          onError: (Object e) => state = HubTripState(step: state.step, positionError: e),
        );
    ref.onDispose(() => _sub?.cancel());
    return const HubTripState();
  }

  Future<void> _onPosition(LatLng position) async {
    final shift = ref.read(todayShiftProvider).value;
    if (shift == null) return;
    state = HubTripState(position: position, step: state.step);
    final step = await ref.read(nextHubStepUseCaseProvider)(position, shift.hub.point);
    if (!ref.mounted) return;
    state = HubTripState(position: position, step: step);
    final arrive = ref.read(arriveAtHubUseCaseProvider);
    if (!_arriving && shift.phase == ShiftPhase.headingToHub && arrive.isAtHub(shift, position)) {
      _arriving = true;
      try {
        await arrive(ref.read(currentUidProvider)!, shift);
      } catch (_) {
        // No frame for this (e.g. the shift couldn't start at the node): the
        // next position tries again.
        _arriving = false;
      }
    }
  }
}

final hubTripViewModelProvider = NotifierProvider.autoDispose<HubTripViewModel, HubTripState>(HubTripViewModel.new);
