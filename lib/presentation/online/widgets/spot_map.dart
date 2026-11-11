import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/map_view.dart';
import '../../../core/widgets/rider/rider_ui.dart';
import '../../../domain/entities/shift.dart';
import '../../../core/constants/app_numbers.dart';
import '../../../core/constants/app_sizes.dart';

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
    this.riderLabelLeft = AppSizes.s33,
    this.riderPx = AppSizes.s128,
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


  @override
  Widget build(BuildContext context) {
    final point = spot.point;
    final me = rider;
    final metersPerPxAt0 = AppMapConfig.metersPerPxAtZoom0 * math.cos(point.latitudeInRad);
    var zoom = AppMapConfig.waitingZoom;
    if (me != null) {
      final meters = const Distance().as(LengthUnit.Meter, me, point);
      if (meters > 0) zoom = (math.log(metersPerPxAt0 * riderPx / meters) / math.ln2).clamp(AppSizes.s5_0, AppSizes.s19_0);
    }
    final metersPerPx = metersPerPxAt0 / math.pow(2, zoom);
    // The map's centre is at height / 2.
    final south = (height / 2 - spotY) * metersPerPx / AppMapConfig.metersPerDegreeLatitude;
    return MapView(
      center: LatLng(point.latitude - south, point.longitude),
      zoom: zoom,
      markers: [
        if (me != null)
          MapMarker(
            point: me,
            width: RiderMapYouMarker.width,
            height: RiderMapYouMarker.height,
            child: RiderMapYouMarker(riderLabel, labelLeft: riderLabelLeft),
          ),
        MapMarker(
          point: point,
          width: RiderMapPlaceMarker.width,
          height: RiderMapPlaceMarker.height,
          child: RiderMapPlaceMarker(spotLabel, centered: centeredLabel),
        ),
      ],
    );
  }
}
