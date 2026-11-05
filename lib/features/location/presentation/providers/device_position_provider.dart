import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../di/location_di.dart';

/// Live device position, while listened to.
final devicePositionProvider =
    StreamProvider.autoDispose<LatLng>((ref) => ref.watch(watchDevicePositionUseCaseProvider)());
