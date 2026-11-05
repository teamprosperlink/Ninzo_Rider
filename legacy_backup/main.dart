import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firebase_options.dart';
import 'screens/home_router.dart';
import 'screens/login_screen.dart';
import 'services/app_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppSession.init();
  runApp(const NinzoRiderApp());
}

class NinzoRiderApp extends StatelessWidget {
  const NinzoRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NinzoRider',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AppSession.isLoggedIn ? homeScreenFor(AppSession.mode) : const LoginScreen(),
    );
  }
}
