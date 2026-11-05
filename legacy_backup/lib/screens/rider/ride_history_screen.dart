import 'package:flutter/material.dart';

import '../../models/ride.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key, required this.rides});

  final List<Ride> rides;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rides')),
      body: rides.isEmpty
          ? const Center(child: Text('No rides yet'))
          : ListView.separated(
              itemCount: rides.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final ride = rides[i];
                return ListTile(
                  leading: Icon(ride.vehicle.icon),
                  title: Text('${ride.pickup.name} → ${ride.drop.name}'),
                  subtitle: Text('${ride.vehicle.label} • ${ride.distanceKm.toStringAsFixed(1)} km'),
                  trailing: Text(rupees(ride.fare), style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }
}
