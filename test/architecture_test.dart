import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Presentation ──> Domain <── Data. `di/` is the one place that knows both
/// sides. Demo pills (`demo_*.dart`) play the backend in demo mode, so they
/// may reach the demo repositories.
void main() {
  Iterable<File> dartFiles(bool Function(String path) where) => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && where(f.path.replaceAll(r'\', '/')));

  final importOf = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

  List<String> importing(Iterable<File> files, bool Function(String uri) bad) => [
    for (final file in files)
      for (final line in file.readAsLinesSync())
        if (importOf.firstMatch(line)?.group(1) case final uri? when bad(uri)) '${file.path}: $line',
  ];

  bool layer(String path, String name) => RegExp('lib/features/[^/]+/$name/').hasMatch(path);
  bool isDemo(String path) => path.split('/').last.startsWith('demo_');

  test('Domain depends on nothing outside itself', () {
    final bad = importing(dartFiles((p) => layer(p, 'domain')), (uri) {
      if (uri.startsWith('package:')) return !uri.startsWith('package:latlong2/');
      return uri.contains('/data/') || uri.contains('/presentation/') || uri.contains('/di/');
    });
    expect(bad, isEmpty);
  });

  test('Data does not know about presentation or wiring', () {
    final bad = importing(
      dartFiles((p) => layer(p, 'data')),
      (uri) => uri.contains('/presentation/') || uri.contains('/di/'),
    );
    expect(bad, isEmpty);
  });

  test('Presentation does not import the data layer or a backend', () {
    final bad = importing(
      dartFiles((p) => layer(p, 'presentation')),
      (uri) =>
          uri.contains('/data/') ||
          uri.startsWith('package:firebase') ||
          uri.startsWith('package:cloud_firestore') ||
          uri.startsWith('package:geolocator') ||
          uri.startsWith('package:shared_preferences'),
    );
    expect(bad, isEmpty);
  });

  test('ViewModels reach repositories only through use cases', () {
    final repository = RegExp(
      r'\w*RepositoryProvider\b|\b(riderLocation|shiftNotifier|stockScanStore|handoverStore|photoSource|riderDirectory)Provider\b',
    );
    final bad = [
      for (final file in dartFiles((p) => layer(p, 'presentation') && !isDemo(p)))
        for (final line in file.readAsLinesSync())
          if (repository.hasMatch(line)) '${file.path}: $line',
    ];
    expect(bad, isEmpty);
  });

  test('Views talk to ViewModels, not to the wiring', () {
    final bad = importing(
      dartFiles((p) => p.contains('/presentation/views/')),
      (uri) => uri.contains('/di/') && !uri.endsWith('core/di/clock_provider.dart'),
    );
    expect(bad, isEmpty);
  });
}
