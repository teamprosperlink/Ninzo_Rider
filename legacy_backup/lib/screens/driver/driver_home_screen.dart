import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data/mock_data.dart';
import '../../models/ride.dart';
import '../../services/app_session.dart';
import '../../services/driver_controller.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/map_view.dart';
import 'driver_trip_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _controller = AppSession.driver;

  void _accept() {
    _controller.accept();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DriverTripScreen(controller: _controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final request = c.request;
        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: Text(c.online ? 'Online' : 'Offline'),
            actions: [
              Switch(value: c.online, onChanged: c.setOnline),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              MapView(
                center: MockData.currentLocation.point,
                zoom: 13,
                markers: [
                  vehicleMarker(MockData.currentLocation.point, Icons.navigation),
                  if (request != null) ...[
                    mapPin(request.pickup.point, Icons.my_location, AppTheme.pickupColor),
                    mapPin(request.drop.point, Icons.location_on, AppTheme.dropColor),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _EarningsCard(earnings: c.earningsToday, trips: c.tripsToday),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: request != null ? _requestCard(context, request) : _statusCard(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusCard(BuildContext context) {
    final online = _controller.online;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              online ? 'Looking for rides near you...' : "You're offline",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (online)
              const LinearProgressIndicator()
            else
              FilledButton(onPressed: () => _controller.setOnline(true), child: const Text('Go Online')),
          ],
        ),
      ),
    );
  }

  Widget _requestCard(BuildContext context, Ride request) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(request.vehicle.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('New ${request.vehicle.label} ride', style: theme.textTheme.titleMedium),
                ),
                Text(rupees(request.fare), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _controller.requestSecondsLeft / DriverController.requestTimeoutSeconds,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.my_location, color: AppTheme.pickupColor),
              title: Text(request.pickup.name),
              subtitle: Text(request.pickup.address),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.location_on, color: AppTheme.dropColor),
              title: Text(request.drop.name),
              subtitle: Text('${request.distanceKm.toStringAsFixed(1)} km trip • ${request.riderName}'),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _controller.reject, child: const Text('Reject')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _accept,
                    child: Text('Accept (${_controller.requestSecondsLeft}s)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.earnings, required this.trips});

  final double earnings;
  final int trips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today's earnings"),
                  Text(rupees(earnings), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Trips'),
                Text('$trips', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
