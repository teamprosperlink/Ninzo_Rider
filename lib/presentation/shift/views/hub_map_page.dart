import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/shift.dart';
import '../viewmodels/hub_trip_view_model.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

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
          if (me != null) MapMarker(
              point: me,
              width: RiderMapYouMarker.width,
              height: RiderMapYouMarker.height,
              child: RiderMapYouMarker(away),
            ),
          MapMarker(
            point: hub.point,
            width: RiderMapPlaceMarker.width,
            height: RiderMapPlaceMarker.height,
            child: RiderMapPlaceMarker(hub.name),
          ),
        ],
      ),
      overlays: [
        if (step != null && step.instruction.isNotEmpty) RiderMapCard(leading: RiderTurnTile(left: step.turnsLeft), title: step.instruction, subtitle: step.street),
      ],
      sheet: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const RiderStatusPill.offline(label: AppStrings.onTheWay),
            const SizedBox(height: AppSizes.s8),
            Text(AppStrings.headingTo(hub.name), style: RiderText.h4),
            const SizedBox(height: AppSizes.s8),
            Text(
              AppStrings.loadYourStockThereThenHead(away.isEmpty ? '' : AppStrings.youReAway(away)),
              style: RiderText.bodyMedium.copyWith(color: RiderColors.grey),
            ),
          ],
        ),
        RiderButton(
          turnButtonLabel(step?.maneuver, away),
          leading: RiderTurnRightIcon(left: step?.turnsLeft ?? false),
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


  static _Framing of(LatLng hub, LatLng? me) {
    final latitude = hub.latitudeInRad;
    var zoom = AppMapConfig.hubZoom;
    if (me != null) {
      final meters = const Distance().as(LengthUnit.Meter, me, hub);
      if (meters > 0) {
        final fit = math.log(AppMapConfig.metersPerPxAtZoom0 * math.cos(latitude) * RiderLayout.hubMapDistancePx / meters) / math.ln2;
        zoom = fit.clamp(AppSizes.s5_0, AppSizes.s17_0);
      }
    }
    final metersPerPx = AppMapConfig.metersPerPxAtZoom0 * math.cos(latitude) / math.pow(2, zoom);
    final south = RiderLayout.hubMapAboveCentrePx * metersPerPx / AppMapConfig.metersPerDegreeLatitude;
    return _Framing(LatLng(hub.latitude - south, hub.longitude), zoom);
  }
}
