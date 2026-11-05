import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves each screenshot the on-device test takes to build/screens/.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final file = File('build/screens/$name.png');
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);
        return true;
      },
    );
