import 'package:flutter/material.dart';

import '../models/ride.dart';
import '../screens/driver/driver_registration_screen.dart';
import '../screens/home_router.dart';
import '../screens/login_screen.dart';
import '../services/app_session.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.items = const []});

  final List<Widget> items;

  Future<void> _switchMode(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (AppSession.hasActiveRide) {
      navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish or cancel your current ride before switching mode')),
      );
      return;
    }
    final target = AppSession.mode == AppMode.rider ? AppMode.driver : AppMode.rider;
    if (target == AppMode.driver && AppSession.driverProfile == null) {
      navigator.pop();
      navigator.push(MaterialPageRoute(builder: (_) => const DriverRegistrationScreen()));
      return;
    }
    await AppSession.setMode(target);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => homeScreenFor(target)),
      (_) => false,
    );
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await AppSession.logout();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDriver = AppSession.mode == AppMode.driver;
    final profile = AppSession.driverProfile;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: scheme.primaryContainer),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 30)),
                const SizedBox(height: 12),
                Text(profile?.name ?? '+91 ${AppSession.phone}', style: Theme.of(context).textTheme.titleMedium),
                Text(isDriver ? 'Driver mode • ${profile?.vehicleNumber ?? ''}' : 'Rider mode'),
              ],
            ),
          ),
          ListTile(
            leading: Icon(isDriver ? Icons.person_pin_circle : Icons.badge),
            title: Text(isDriver ? 'Switch to Rider mode' : 'Switch to Driver mode'),
            subtitle: Text(isDriver
                ? 'Book a ride for yourself'
                : (profile == null ? 'Register as a driver' : 'Go online and earn')),
            onTap: () => _switchMode(context),
          ),
          const Divider(),
          ...items,
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
