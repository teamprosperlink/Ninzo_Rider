import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/map_view.dart';
import '../../../../core/widgets/rider/rider_ui.dart';

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
  });

  final LatLng gate;
  final String gateLabel;

  /// The map's height.
  final double height;
  final double gateY;
  final LatLng? rider;
  final String riderLabel;

  static const _metersPerPxAtZoom0 = 156543.03;
  static const _defaultZoom = 16.0;

  /// How far from the gate the design draws the rider: (meters, pixels). The
  /// map zooms in as they get closer.
  static const _framing = [(100.0, 38.0), (300.0, 67.0), (600.0, 128.0)];

  static double _riderPx(double meters) {
    if (meters <= _framing.first.$1) return _framing.first.$2;
    for (var i = 1; i < _framing.length; i++) {
      final (m0, p0) = _framing[i - 1];
      final (m1, p1) = _framing[i];
      if (meters <= m1) return p0 + (p1 - p0) * (meters - m0) / (m1 - m0);
    }
    return _framing.last.$2;
  }

  @override
  Widget build(BuildContext context) {
    final me = rider;
    final metersPerPxAt0 = _metersPerPxAtZoom0 * math.cos(gate.latitudeInRad);
    var zoom = _defaultZoom;
    if (me != null) {
      final meters = const Distance().as(LengthUnit.Meter, me, gate);
      if (meters > 0) zoom = (math.log(metersPerPxAt0 * _riderPx(meters) / meters) / math.ln2).clamp(5.0, 19.0);
    }
    final metersPerPx = metersPerPxAt0 / math.pow(2, zoom);
    // The map's centre is at height / 2.
    final south = (height / 2 - gateY) * metersPerPx / 111320;
    return MapView(
      center: LatLng(gate.latitude - south, gate.longitude),
      zoom: zoom,
      attributionInset: RiderMapLayout.underSheetOverlap,
      layers: [
        MarkerLayer(
          markers: [
            Marker(
              point: gate,
              width: RiderDeliveryRadius.size,
              height: RiderDeliveryRadius.size,
              child: const RiderDeliveryRadius(),
            ),
          ],
        ),
        if (me != null)
          PolylineLayer(
            polylines: [
              // Across, then down to the rider, as drawn.
              Polyline(
                points: [gate, LatLng(gate.latitude, me.longitude), me],
                color: RiderColors.brand,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                strokeJoin: StrokeJoin.round,
              ),
            ],
          ),
      ],
      markers: [
        Marker(
          point: gate,
          width: RiderMapPlaceMarker.width,
          height: RiderMapPlaceMarker.height,
          child: RiderMapPlaceMarker(gateLabel, centered: true, pulse: 60, pulseAlpha: 0.15),
        ),
        if (me != null)
          Marker(
            point: me,
            width: RiderMapRiderPuck.width,
            height: RiderMapRiderPuck.height,
            child: RiderMapRiderPuck(riderLabel),
          ),
      ],
    );
  }
}
