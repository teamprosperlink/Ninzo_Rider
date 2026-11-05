import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/ride.dart';
import '../../services/rider_controller.dart';
import '../../widgets/map_view.dart';

class RideTrackingScreen extends StatelessWidget {
  const RideTrackingScreen({super.key, required this.controller});

  final RiderController controller;

  static String _title(RideStatus status) => switch (status) {
        RideStatus.searching => 'Finding your ride',
        RideStatus.driverAssigned => 'Driver on the way',
        RideStatus.driverArrived => 'Driver has arrived',
        RideStatus.inProgress => 'On trip',
        RideStatus.completed => 'Trip completed',
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ride = controller.ride;
        if (ride == null) return const Scaffold();
        final driverAt = controller.driverLocation;
        return PopScope(
          canPop: false,
          child: Scaffold(
            appBar: AppBar(title: Text(_title(ride.status)), automaticallyImplyLeading: false),
            body: Column(
              children: [
                Expanded(
                  child: MapView(
                    center: ride.pickup.point,
                    zoom: 13,
                    markers: [
                      mapPin(ride.pickup.point, Icons.my_location, AppTheme.pickupColor),
                      mapPin(ride.drop.point, Icons.location_on, AppTheme.dropColor),
                      if (driverAt != null) vehicleMarker(driverAt, ride.vehicle.icon),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildPanel(context, ride),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanel(BuildContext context, Ride ride) {
    final theme = Theme.of(context);
    switch (ride.status) {
      case RideStatus.searching:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Looking for a ${ride.vehicle.label} near you...', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            _cancelButton(context),
          ],
        );
      case RideStatus.completed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.pickupColor, size: 56),
            const SizedBox(height: 8),
            Text('You reached ${ride.drop.name}', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              rupees(ride.fare),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Text('Please pay cash to the driver', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const _RatingBar(),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                controller.finishRide();
              },
              child: const Text('Done'),
            ),
          ],
        );
      case RideStatus.driverAssigned:
      case RideStatus.driverArrived:
      case RideStatus.inProgress:
        final driver = ride.driver!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(driver.name[0])),
              title: Text(driver.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${driver.vehicleModel} • ${driver.vehicleNumber}\n★ ${driver.rating}'),
              isThreeLine: true,
              trailing: IconButton.filledTonal(
                icon: const Icon(Icons.call),
                onPressed: () => ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Calling ${driver.name}...'))),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(child: Text('To: ${ride.drop.name}', style: theme.textTheme.bodyLarge)),
                Text(rupees(ride.fare), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            if (ride.status != RideStatus.inProgress) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Share OTP with driver: ${ride.otp}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ),
            ],
            if (ride.status == RideStatus.driverAssigned) ...[
              const SizedBox(height: 12),
              _cancelButton(context),
            ],
          ],
        );
    }
  }

  Widget _cancelButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        Navigator.pop(context);
        controller.cancelRide();
      },
      child: const Text('Cancel Ride'),
    );
  }
}

class _RatingBar extends StatefulWidget {
  const _RatingBar();

  @override
  State<_RatingBar> createState() => _RatingBarState();
}

class _RatingBarState extends State<_RatingBar> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            icon: Icon(i <= _rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
            onPressed: () => setState(() => _rating = i),
          ),
      ],
    );
  }
}
