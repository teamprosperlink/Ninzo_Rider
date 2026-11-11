import 'dart:async';

import 'package:ninzo_rider/core/widgets/map_view.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MapView.showBaseMap = false;
  await testMain();
}
