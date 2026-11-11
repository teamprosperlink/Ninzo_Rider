import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_numbers.dart';

/// The map of Order 01–03 and Navigate 01–03: the gate at [gateY] pixels from
/// the top of the screen inside the dashed delivery radius, the route, and the
/// rider with the distance under them.
class GateMap extends StatelessWidget {
  const GateMap({
    super.key,
    required this.gate,
    required this.gateLabel,
    required this.height,
    required this.gateY,
    this.rider,
    this.riderLabel = '',
    this.road = const [],
  });

  final LatLng gate;
  final String gateLabel;

  /// The map's height.
  final double height;
  final double gateY;
  final LatLng? rider;
  final String riderLabel;

  /// The road to the gate; without it, the line the design draws.
  final List<LatLng> road;



  static double _riderPx(double meters) {
    if (meters <= AppMapConfig.gateFraming.first.$1) return AppMapConfig.gateFraming.first.$2;
    for (var i = 1; i < AppMapConfig.gateFraming.length; i++) {
      final (m0, p0) = AppMapConfig.gateFraming[i - 1];
      final (m1, p1) = AppMapConfig.gateFraming[i];
      if (meters <= m1) return p0 + (p1 - p0) * (meters - m0) / (m1 - m0);
    }
    return AppMapConfig.gateFraming.last.$2;
  }

  @override
  Widget build(BuildContext context) {
    final me = rider;
    final metersPerPxAt0 = AppMapConfig.metersPerPxAtZoom0 * math.cos(gate.latitudeInRad);
    var zoom = AppMapConfig.gateZoom;
    if (me != null) {
      final meters = const Distance().as(LengthUnit.Meter, me, gate);
      if (meters > 0) zoom = (math.log(metersPerPxAt0 * _riderPx(meters) / meters) / math.ln2).clamp(AppSizes.s5_0, AppSizes.s19_0);
    }
    final metersPerPx = metersPerPxAt0 / math.pow(2, zoom);
    // The map's centre is at height / 2.
    final south = (height / 2 - gateY) * metersPerPx / AppMapConfig.metersPerDegreeLatitude;
    return MapView(
      center: LatLng(gate.latitude - south, gate.longitude),
      zoom: zoom,
      underMarkers: [
        MapMarker(
          point: gate,
          width: RiderDeliveryRadius.size,
          height: RiderDeliveryRadius.size,
          child: const RiderDeliveryRadius(),
        ),
      ],
      lines: [
        if (road.isNotEmpty)
          MapLine(points: road, color: RiderColors.brand, width: AppSizes.s4)
        else if (me != null)
          // Across, then down to the rider, as drawn.
          MapLine(points: [gate, LatLng(gate.latitude, me.longitude), me], color: RiderColors.brand, width: AppSizes.s4),
      ],
      markers: [
        MapMarker(
          point: gate,
          width: RiderMapPlaceMarker.width,
          height: RiderMapPlaceMarker.height,
          child: RiderMapPlaceMarker(gateLabel, centered: true, pulse: AppSizes.s60, pulseAlpha: AppOpacity.o0_15),
        ),
        if (me != null)
          MapMarker(
            point: me,
            width: RiderMapRiderPuck.width,
            height: RiderMapRiderPuck.height,
            child: RiderMapRiderPuck(riderLabel),
          ),
      ],
    );
  }
}
