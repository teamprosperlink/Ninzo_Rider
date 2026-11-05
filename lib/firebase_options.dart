// Firebase config for project `ninzo-rider`, matching
// android/app/google-services.json and ios/Runner/GoogleService-Info.plist.
// Regenerate with `flutterfire configure --project=ninzo-rider` when adding
// platforms or apps.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web.');
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError('Firebase is not configured for $defaultTargetPlatform.'),
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyA2Ce0E4h6roOJZMadF3wf99O9zMasC3aA',
    appId: '1:989018069150:android:d30237c8572ad88e63038f',
    messagingSenderId: '989018069150',
    projectId: 'ninzo-rider',
    storageBucket: 'ninzo-rider.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCQPdyG93sTffOztQXg6sGyCRtm0SRpU6M',
    appId: '1:989018069150:ios:5f62558a458e181963038f',
    messagingSenderId: '989018069150',
    projectId: 'ninzo-rider',
    storageBucket: 'ninzo-rider.firebasestorage.app',
    iosBundleId: 'com.prosperlink.ninzoRider',
  );
}
