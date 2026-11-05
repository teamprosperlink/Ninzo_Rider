import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/launcher.dart';
import '../../../../core/widgets/map_view.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../domain/entities/shift.dart';
import '../viewmodels/hub_trip_view_model.dart';

/// Shift 52 "Heading to hub": map with the hub and the rider, the next
/// turn, and directions. Arriving moves on by itself (Shift 53 or the
/// stock).
class HubMapPage extends ConsumerWidget {
  const HubMapPage({super.key, required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(hubTripViewModelProvider);
    final hub = shift.hub;
    final me = trip.position;
    final km = trip.step?.totalKm ?? shift.hubDistanceKm;
    final away = km == null ? '' : distance(km);
    final step = trip.step;
    final framing = _Framing.of(hub.point, me);
    return RiderMapLayout(
      map: MapView(
        center: framing.center,
        zoom: framing.zoom,
        markers: [
          if (me != null) Marker(
              point: me,
              width: RiderMapYouMarker.width,
              height: RiderMapYouMarker.height,
              child: RiderMapYouMarker(away),
            ),
          Marker(
            point: hub.point,
            width: RiderMapPlaceMarker.width,
            height: RiderMapPlaceMarker.height,
            child: RiderMapPlaceMarker(hub.name),
          ),
        ],
      ),
      overlays: [
        if (step != null && step.instruction.isNotEmpty) RiderMapCard(leading: const RiderTurnTile(), title: step.instruction, subtitle: step.street),
      ],
      sheet: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RiderStatusPill.offline(label: 'On the way'),
            const SizedBox(height: 8),
            Text('Heading to ${hub.name}', style: RiderText.h4),
            const SizedBox(height: 8),
            Text(
              '${away.isEmpty ? '' : 'You’re $away away. '}Load your stock there, then head to your spot.',
              style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
            ),
          ],
        ),
        RiderButton(
          turnButtonLabel(step?.maneuver, away),
          leading: const RiderTurnRightIcon(),
          onPressed: () => openDirections(hub.point),
        ),
      ],
    );
  }
}

/// Keeps the hub just above the map's centre and the rider about 128px from
/// it, wherever they are, as the design composes the map.
class _Framing {
  const _Framing(this.center, this.zoom);

  final LatLng center;
  final double zoom;

  static const _distancePx = 128.0;
  static const _hubAboveCentrePx = 20.0;

  static _Framing of(LatLng hub, LatLng? me) {
    const metersPerPxAtZoom0 = 156543.03;
    final latitude = hub.latitudeInRad;
    var zoom = 15.0;
    if (me != null) {
      final meters = const Distance().as(LengthUnit.Meter, me, hub);
      if (meters > 0) {
        final fit = math.log(metersPerPxAtZoom0 * math.cos(latitude) * _distancePx / meters) / math.ln2;
        zoom = fit.clamp(5.0, 17.0);
      }
    }
    final metersPerPx = metersPerPxAtZoom0 * math.cos(latitude) / math.pow(2, zoom);
    final south = _hubAboveCentrePx * metersPerPx / 111320;
    return _Framing(LatLng(hub.latitude - south, hub.longitude), zoom);
  }
}
