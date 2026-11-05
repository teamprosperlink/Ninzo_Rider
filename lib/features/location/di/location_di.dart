import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/geolocator_location_repository.dart';
import '../domain/repositories/location_repository.dart';
import '../domain/usecases/watch_device_position.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) => GeolocatorLocationRepository());

final watchDevicePositionUseCaseProvider =
    Provider((ref) => WatchDevicePosition(ref.watch(locationRepositoryProvider)));
