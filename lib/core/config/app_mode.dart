/// Demo mode runs the whole app on in-memory sample data (no Firebase
/// backend needed), so every screen can be tried on a phone:
///
///   flutter run --dart-define=DEMO=true
///
/// Each feature's `di/` file picks its demo repository when this is true.
const kDemoMode = bool.fromEnvironment('DEMO');
