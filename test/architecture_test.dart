import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Presentation ──> Domain <── Data. `injection_container.dart` is the one place that knows both
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

  bool layer(String path, String name) => path.startsWith('lib/$name/');
  bool isDemo(String path) => path.split('/').last.startsWith('demo_');

  test('Domain depends on nothing outside itself', () {
    final bad = importing(dartFiles((p) => layer(p, 'domain')), (uri) {
      if (uri.startsWith('package:')) return !uri.startsWith('package:latlong2/');
      return uri.contains('/data/') || uri.contains('/presentation/') || (uri.endsWith('injection_container.dart') || uri.contains('/core/network/'));
    });
    expect(bad, isEmpty);
  });

  test('Data does not know about presentation or wiring', () {
    final bad = importing(
      dartFiles((p) => layer(p, 'data')),
      (uri) => uri.contains('/presentation/') || uri.endsWith('injection_container.dart'),
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
      dartFiles((p) => RegExp('^lib/presentation/[^/]+/(views|widgets)/').hasMatch(p) && !isDemo(p)),
      (uri) => uri.endsWith('injection_container.dart') || uri.contains('/core/network/'),
    );
    expect(bad, isEmpty);
  });

  test('Colours and font styles come only from core/constants and core/theme', () {
    final hardcoded = RegExp(r'Color\(0x|(?<![A-Za-z])Colors\.[a-z]|\bTextStyle\(|fontFamily:|fontSize:');
    final bad = [
      for (final file in dartFiles(
        (p) => p.startsWith('lib/') && !p.startsWith('lib/core/constants/') && !p.startsWith('lib/core/theme/'),
      ))
        for (final line in file.readAsLinesSync())
          if (hardcoded.hasMatch(line) && !line.trimLeft().startsWith('//')) '${file.path}: $line',
    ];
    expect(bad, isEmpty);
  });

  test('Sizes, durations and text come only from core/constants', () {
    final hardcoded = RegExp(
      r"EdgeInsets\.\w+\(\s*(\w+:\s*)?-?\d|\b(width|height|size|left|top|right|bottom):\s*\d+(\.\d+)?\s*[,)]|BorderRadius\.circular\(\s*\d|Duration\(\s*\w+:\s*\d|\bText\(\s*'[^']*[A-Za-z]",
    );
    final interpolation = RegExp(r'\$\{[^}]*\}|\$\w+');
    final bad = [
      for (final file in dartFiles((p) => p.startsWith('lib/presentation/') || p.startsWith('lib/core/widgets/')))
        for (final line in file.readAsLinesSync())
          if (hardcoded.hasMatch(line.replaceAll(interpolation, '')) && !line.trimLeft().startsWith('//'))
            '${file.path}: $line',
    ];
    expect(bad, isEmpty);
  });

  test('Screens have no number, text, shadow or constant of their own', () {
    final interpolation = RegExp(r'\$\{[^{}]*\}|\$\w+');
    final quoted = RegExp("'[^']*'" r'|"[^"]*"');
    // 0, 1 and 2 stay: loop counters, halves and checks like `i > 0`.
    final number = RegExp(r'(?<![\w.])(0x[0-9A-Fa-f]+|\d+\.\d+|[3-9]|\d{2,})(?![\w.])');
    final hasText = RegExp(r'\S');
    final shadow = RegExp(r'\bBoxShadow\(');
    final constant = RegExp(r'^(const \w|\s+static const )');
    final bad = <String>[];
    for (final file in dartFiles((p) => p.startsWith('lib/presentation/') || p.startsWith('lib/core/widgets/'))) {
      final isScreen = file.path.replaceAll(r'\', '/').startsWith('lib/presentation/');
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('import ') || trimmed.startsWith('export ')) continue;
        final strings = line.replaceAll(interpolation, '');
        final code = strings.replaceAll(quoted, '').split('//').first;
        if (number.hasMatch(code) ||
            quoted.allMatches(strings.split(' //').first).any((m) => hasText.hasMatch(m[0]!.substring(1, m[0]!.length - 1))) ||
            shadow.hasMatch(code) ||
            (isScreen && constant.hasMatch(code))) {
          bad.add('${file.path}: $line');
        }
      }
    }
    expect(bad, isEmpty);
  });
}
