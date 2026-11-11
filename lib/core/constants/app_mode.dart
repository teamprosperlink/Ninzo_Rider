import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Which backend the app talks to:
///
///   flutter run                         → the Ninzo rider API (`STAGING_API_URL` in `.env`)
///   flutter run --dart-define=DEMO=true → demo: in-memory sample data, no backend
///
/// `injection_container.dart` picks each feature's repository from these.
const kDemoMode = bool.fromEnvironment('DEMO');

/// `--dart-define=DEMO_SIM_RIDER=true`: the demo rider moves by itself, on sample
/// turns. Without it the demo uses the phone's GPS and Google's routes.
const kDemoSimulatedRider = kDemoMode && bool.fromEnvironment('DEMO_SIM_RIDER');

/// The Ninzo rider API: the app's backend unless the build asks for the demo
/// (`DEMO=true`); `DEMO=true RIDER_API=true` is the API too. Tests (`flutter
/// test`, and `integration_test/` with `RIDER_API=false`) keep the flow their
/// fakes are written for; their repositories are the fakes either way.
final bool kRiderApi = _riderApiSet ? _riderApiDefine : !kDemoMode && !_inFlutterTest;

const _riderApiSet = bool.hasEnvironment('RIDER_API');
const _riderApiDefine = bool.fromEnvironment('RIDER_API');

bool get _inFlutterTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// The "Demo: …" pills that play the next step. Not on the rider API: there
/// the server drives what happens.
final bool kDemoControls = kDemoMode && !kRiderApi;
