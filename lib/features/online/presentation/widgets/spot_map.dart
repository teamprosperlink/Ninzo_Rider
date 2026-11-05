import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/map_view.dart';
import '../../../../core/widgets/rider/rider_ui.dart';
import '../../../shift/domain/entities/shift.dart';

/// The map of Shift 19–35: the spot's dot at [spotY] pixels from the top of
/// the screen with its label, and optionally the rider, framed about
/// [riderPx] pixels from the spot wherever they are.
class SpotMap extends StatelessWidget {
  const SpotMap({
    super.key,
    required this.spot,
    required this.height,
    required this.spotY,
    required this.spotLabel,
    this.centeredLabel = false,
    this.rider,
    this.riderLabel = '',
    this.riderLabelLeft = 33,
    this.riderPx = 128,
  });

  final Spot spot;

  /// The map's height.
  final double height;
  final double spotY;
  final String spotLabel;
  final bool centeredLabel;
  final LatLng? rider;
  final String riderLabel;
  final double riderLabelLeft;
  final double riderPx;

  static const _metersPerPxAtZoom0 = 156543.03;
  static const _waitingZoom = 16.0;

  @override
  Widget build(BuildContext context) {
    final point = spot.point;
    final me = rider;
    final metersPerPxAt0 = _metersPerPxAtZoom0 * math.cos(point.latitudeInRad);
    var zoom = _waitingZoom;
    if (me != null) {
      final meters = const Distance().as(LengthUnit.Meter, me, point);
      if (meters > 0) zoom = (math.log(metersPerPxAt0 * riderPx / meters) / math.ln2).clamp(5.0, 19.0);
    }
    final metersPerPx = metersPerPxAt0 / math.pow(2, zoom);
    // The map's centre is at height / 2.
    final south = (height / 2 - spotY) * metersPerPx / 111320;
    return MapView(
      center: LatLng(point.latitude - south, point.longitude),
      zoom: zoom,
      attributionInset: RiderMapLayout.underSheetOverlap,
      markers: [
        if (me != null)
          Marker(
            point: me,
            width: RiderMapYouMarker.width,
            height: RiderMapYouMarker.height,
            child: RiderMapYouMarker(riderLabel, labelLeft: riderLabelLeft),
          ),
        Marker(
          point: point,
          width: RiderMapPlaceMarker.width,
          height: RiderMapPlaceMarker.height,
          child: RiderMapPlaceMarker(spotLabel, centered: centeredLabel),
        ),
      ],
    );
  }
}
